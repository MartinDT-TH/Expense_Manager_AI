using Microsoft.EntityFrameworkCore;
using MoneyManager.Application.DTOs.Report;
using MoneyManager.Application.Interfaces;
using MoneyManager.Domain.Enums;
using MoneyManager.Infrastructure.Data.Context;
using ClosedXML.Excel;
using System.Globalization;
using System.Text;

namespace MoneyManager.Infrastructure.Services;

public class ReportService : IReportService
{
    private readonly MoneyManagerDbContext _context;

    public ReportService(MoneyManagerDbContext context)
    {
        _context = context;
    }

    public async Task<SummaryReportResponse> GetSummaryAsync(ReportFilterRequest request, Guid userId)
    {
        var query = await GetBaseQueryAsync(userId, request);
        var transactions = await query.ToListAsync();

        var totalIncome = transactions.Where(t => t.Category!.Type == CategoryType.Income).Sum(t => t.Amount);
        var totalExpense = transactions.Where(t => t.Category!.Type == CategoryType.Expense).Sum(t => t.Amount);
        var days = (request.EndDate - request.StartDate).Days + 1;

        var response = new SummaryReportResponse
        {
            TotalIncome = totalIncome,
            TotalExpense = totalExpense,
            NetBalance = totalIncome - totalExpense,
            TransactionCount = transactions.Count,
            AvgDailyIncome = days > 0 ? totalIncome / days : 0,
            AvgDailyExpense = days > 0 ? totalExpense / days : 0,
            StartDate = request.StartDate,
            EndDate = request.EndDate
        };

        var prevStartDate = request.StartDate.AddDays(-days);
        var prevEndDate = request.StartDate.AddDays(-1);
        var prevRequest = new ReportFilterRequest { StartDate = prevStartDate, EndDate = prevEndDate, WalletId = request.WalletId, Currency = request.Currency };
        var prevQuery = await GetBaseQueryAsync(userId, prevRequest);
        var prevTransactions = await prevQuery.ToListAsync();
        var prevIncome = prevTransactions.Where(t => t.Category!.Type == CategoryType.Income).Sum(t => t.Amount);
        var prevExpense = prevTransactions.Where(t => t.Category!.Type == CategoryType.Expense).Sum(t => t.Amount);

        if (prevIncome > 0 || prevExpense > 0)
        {
            response.Comparison = new ComparisonData
            {
                IncomeChangePercent = prevIncome > 0 ? Math.Round((totalIncome - prevIncome) / prevIncome * 100, 2) : (totalIncome > 0 ? 100 : 0),
                ExpenseChangePercent = prevExpense > 0 ? Math.Round((totalExpense - prevExpense) / prevExpense * 100, 2) : (totalExpense > 0 ? 100 : 0),
                IncomeTrend = GetTrend(totalIncome, prevIncome),
                ExpenseTrend = GetTrend(totalExpense, prevExpense)
            };
        }

        return response;
    }

    public async Task<CategoryReportResponse> GetByCategoryAsync(ReportFilterRequest request, Guid userId)
    {
        var query = await GetBaseQueryAsync(userId, request);
        var transactions = await query.ToListAsync();

        var totalExpense = transactions.Where(t => t.Category!.Type == CategoryType.Expense).Sum(t => t.Amount);
        var totalIncome = transactions.Where(t => t.Category!.Type == CategoryType.Income).Sum(t => t.Amount);

        var expenseByCategory = transactions.Where(t => t.Category!.Type == CategoryType.Expense).GroupBy(t => t.Category)
            .Select(g => new CategoryReportItem
            {
                CategoryId = g.Key!.Id,
                CategoryName = g.Key.Name,
                Icon = g.Key.IconCode,
                Amount = g.Sum(t => t.Amount),
                Percentage = totalExpense > 0 ? Math.Round(g.Sum(t => t.Amount) / totalExpense * 100, 2) : 0,
                TransactionCount = g.Count()
            }).OrderByDescending(c => c.Amount).ToList();

        var incomeByCategory = transactions.Where(t => t.Category!.Type == CategoryType.Income).GroupBy(t => t.Category)
            .Select(g => new CategoryReportItem
            {
                CategoryId = g.Key!.Id,
                CategoryName = g.Key.Name,
                Icon = g.Key.IconCode,
                Amount = g.Sum(t => t.Amount),
                Percentage = totalIncome > 0 ? Math.Round(g.Sum(t => t.Amount) / totalIncome * 100, 2) : 0,
                TransactionCount = g.Count()
            }).OrderByDescending(c => c.Amount).ToList();

        return new CategoryReportResponse
        {
            ExpenseByCategory = expenseByCategory,
            IncomeByCategory = incomeByCategory,
            TopExpenseCategories = expenseByCategory.Take(5).ToList()
        };
    }

    public async Task<TimeReportResponse> GetByTimeAsync(ReportFilterRequest request, Guid userId, string groupBy)
    {
        var query = await GetBaseQueryAsync(userId, request);
        var transactions = await query.ToListAsync();

        var data = groupBy.ToLower() switch
        {
            "daily" => GroupByDaily(transactions, request.StartDate, request.EndDate),
            "weekly" => GroupByWeekly(transactions, request.StartDate, request.EndDate),
            "monthly" => GroupByMonthly(transactions, request.StartDate, request.EndDate),
            _ => GroupByDaily(transactions, request.StartDate, request.EndDate)
        };

        return new TimeReportResponse { GroupBy = groupBy, Data = data };
    }

    public async Task<TrendReportResponse> GetTrendAsync(Guid userId)
    {
        var sixMonthsAgo = DateTime.UtcNow.AddMonths(-6);
        var walletIds = await _context.Wallets.Where(w => w.OwnerId == userId && !w.IsDeleted).Select(w => w.Id).ToListAsync();
        var transactions = await _context.Transactions.Include(t => t.Category).Where(t => walletIds.Contains(t.WalletId) && !t.IsDeleted && t.TransactionDate >= sixMonthsAgo).ToListAsync();

        var monthlyData = transactions.GroupBy(t => new { t.TransactionDate.Year, t.TransactionDate.Month })
            .Select(g => new MonthlyTrendItem
            {
                Year = g.Key.Year,
                Month = CultureInfo.CurrentCulture.DateTimeFormat.GetAbbreviatedMonthName(g.Key.Month),
                Expense = g.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount),
                Income = g.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount)
            }).OrderBy(m => m.Year).ThenBy(m => DateTime.ParseExact(m.Month, "MMM", CultureInfo.CurrentCulture).Month).ToList();

        var last3Months = monthlyData.TakeLast(3).ToList();
        var avg3MonthExpense = last3Months.Any() ? last3Months.Average(m => m.Expense) : 0;
        var today = DateTime.UtcNow;
        var daysInMonth = DateTime.DaysInMonth(today.Year, today.Month);
        var currentMonthExpense = monthlyData.FirstOrDefault(m => m.Year == today.Year && DateTime.ParseExact(m.Month, "MMM", CultureInfo.CurrentCulture).Month == today.Month)?.Expense ?? 0;
        var predictedExpense = (currentMonthExpense / today.Day) * daysInMonth;
        var spendingTrend = "Stable";
        if (monthlyData.Count >= 2)
        {
            var recent = monthlyData.TakeLast(2).ToList();
            var changePercent = recent[0].Expense > 0 ? (recent[1].Expense - recent[0].Expense) / recent[0].Expense * 100 : 0;
            if (changePercent > 10) spendingTrend = "Increasing";
            else if (changePercent < -10) spendingTrend = "Decreasing";
        }

        return new TrendReportResponse
        {
            PredictedExpenseThisMonth = Math.Round(predictedExpense, 0),
            Avg3MonthExpense = Math.Round(avg3MonthExpense, 0),
            SpendingTrend = spendingTrend,
            MonthlyTrend = monthlyData,
            Recommendations = GenerateRecommendations(spendingTrend, predictedExpense, avg3MonthExpense)
        };
    }

    public async Task<ExportReportResponse> ExportAsync(ExportReportRequest request, Guid userId, bool isPremium)
    {
        if (!isPremium) throw new InvalidOperationException("Tính năng xuất báo cáo chỉ dành cho tài khoản Premium.");

        var query = await GetBaseQueryAsync(userId, request);
        var transactions = await query.OrderByDescending(t => t.TransactionDate).ToListAsync();
        
        var format = request.Format?.ToUpper() ?? "EXCEL";
        byte[] fileBytes;
        string fileName;

        if (format == "CSV")
        {
            var content = GenerateCsv(transactions);
            fileBytes = Encoding.UTF8.GetBytes(content);
            fileName = $"MoneyManager_Report_{DateTime.UtcNow:yyyyMMdd}.csv";
        }
        else // Default to Excel
        {
            fileBytes = GenerateExcel(transactions, request.StartDate, request.EndDate);
            fileName = $"MoneyManager_Report_{DateTime.UtcNow:yyyyMMdd}.xlsx";
        }

        var base64Content = Convert.ToBase64String(fileBytes);

        return new ExportReportResponse 
        { 
            FileName = fileName, 
            Format = format, 
            Base64Content = base64Content, 
            EmailSent = false 
        };
    }

    private async Task<IQueryable<Domain.Entities.Transaction>> GetBaseQueryAsync(Guid userId, ReportFilterRequest request)
    {
        var walletIds = await _context.Wallets.Where(w => w.OwnerId == userId && !w.IsDeleted).Select(w => w.Id).ToListAsync();
        if (request.WalletId.HasValue) walletIds = walletIds.Where(id => id == request.WalletId.Value).ToList();

        var query = _context.Transactions.Include(t => t.Category).Include(t => t.Wallet)
            .Where(t => walletIds.Contains(t.WalletId) && !t.IsDeleted && t.TransactionDate >= request.StartDate && t.TransactionDate <= request.EndDate);

        if (!string.IsNullOrEmpty(request.Currency) && Enum.TryParse<CurrencyCode>(request.Currency, out var currencyCode))
            query = query.Where(t => t.Wallet!.Currency == currencyCode);

        return query;
    }

    private static string GetTrend(decimal current, decimal previous)
    {
        if (previous == 0) return current > 0 ? "Increase" : "Stable";
        var change = (current - previous) / previous * 100;
        return change > 5 ? "Increase" : (change < -5 ? "Decrease" : "Stable");
    }

    private static List<TimeReportItem> GroupByDaily(List<Domain.Entities.Transaction> transactions, DateTime startDate, DateTime endDate)
    {
        var result = new List<TimeReportItem>();
        for (var current = startDate.Date; current <= endDate.Date; current = current.AddDays(1))
        {
            var dayTransactions = transactions.Where(t => t.TransactionDate.Date == current).ToList();
            result.Add(new TimeReportItem
            {
                Label = current.ToString("dd/MM"),
                Date = current,
                Income = dayTransactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount),
                Expense = dayTransactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount),
                Net = dayTransactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount) - dayTransactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount)
            });
        }
        return result;
    }

    private static List<TimeReportItem> GroupByWeekly(List<Domain.Entities.Transaction> transactions, DateTime startDate, DateTime endDate)
    {
        var result = new List<TimeReportItem>();
        int weekNumber = 1;
        for (var current = startDate.Date; current <= endDate.Date; weekNumber++)
        {
            var weekEnd = current.AddDays(6);
            if (weekEnd > endDate) weekEnd = endDate;
            var weekTransactions = transactions.Where(t => t.TransactionDate.Date >= current && t.TransactionDate.Date <= weekEnd).ToList();
            result.Add(new TimeReportItem
            {
                Label = $"Tuần {weekNumber}",
                Date = current,
                Income = weekTransactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount),
                Expense = weekTransactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount),
                Net = weekTransactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount) - weekTransactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount)
            });
            current = weekEnd.AddDays(1);
        }
        return result;
    }

    private static List<TimeReportItem> GroupByMonthly(List<Domain.Entities.Transaction> transactions, DateTime startDate, DateTime endDate)
    {
        var result = new List<TimeReportItem>();
        for (var current = new DateTime(startDate.Year, startDate.Month, 1); current <= endDate; current = current.AddMonths(1))
        {
            var monthTransactions = transactions.Where(t => t.TransactionDate.Year == current.Year && t.TransactionDate.Month == current.Month).ToList();
            result.Add(new TimeReportItem
            {
                Label = $"Tháng {current.Month}",
                Date = current,
                Income = monthTransactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount),
                Expense = monthTransactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount),
                Net = monthTransactions.Where(t => t.Category?.Type == CategoryType.Income).Sum(t => t.Amount) - monthTransactions.Where(t => t.Category?.Type == CategoryType.Expense).Sum(t => t.Amount)
            });
        }
        return result;
    }

    private static List<string> GenerateRecommendations(string trend, decimal predicted, decimal average)
    {
        var recommendations = new List<string>();
        if (trend == "Increasing") recommendations.Add("Chi tiêu đang có xu hướng tăng. Hãy xem xét lại các khoản chi không cần thiết.");
        if (predicted > average * 1.2m) recommendations.Add($"Dự kiến chi tiêu tháng này cao hơn {Math.Round((predicted / average - 1) * 100)}% so với trung bình 3 tháng.");
        if (trend == "Decreasing") recommendations.Add("Tuyệt vời! Chi tiêu đang giảm. Tiếp tục duy trì thói quen tốt này.");
        if (!recommendations.Any()) recommendations.Add("Chi tiêu của bạn đang ổn định. Tiếp tục theo dõi để đạt mục tiêu tài chính.");
        return recommendations;
    }

    private static byte[] GenerateExcel(List<Domain.Entities.Transaction> transactions, DateTime? startDate, DateTime? endDate)
    {
        using var workbook = new XLWorkbook();
        var worksheet = workbook.Worksheets.Add("Báo cáo");

        // Header styling
        var headerRange = worksheet.Range("A1:F1");
        headerRange.Style.Font.Bold = true;
        headerRange.Style.Fill.BackgroundColor = XLColor.FromHtml("#4CAF50");
        headerRange.Style.Font.FontColor = XLColor.White;
        headerRange.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;

        // Headers
        worksheet.Cell(1, 1).Value = "Ngày";
        worksheet.Cell(1, 2).Value = "Danh mục";
        worksheet.Cell(1, 3).Value = "Loại";
        worksheet.Cell(1, 4).Value = "Số tiền";
        worksheet.Cell(1, 5).Value = "Ghi chú";
        worksheet.Cell(1, 6).Value = "Ví";

        // Data
        int row = 2;
        decimal totalIncome = 0;
        decimal totalExpense = 0;

        foreach (var t in transactions)
        {
            var isIncome = t.Category?.Type == CategoryType.Income;
            var type = isIncome ? "Thu nhập" : "Chi tiêu";
            var amount = t.Amount;

            worksheet.Cell(row, 1).Value = t.TransactionDate.ToString("dd/MM/yyyy");
            worksheet.Cell(row, 2).Value = t.Category?.Name ?? "Không xác định";
            worksheet.Cell(row, 3).Value = type;
            worksheet.Cell(row, 4).Value = amount;
            worksheet.Cell(row, 5).Value = t.Note ?? "";
            worksheet.Cell(row, 6).Value = t.Wallet?.Name ?? "Không xác định";

            // Color coding for amount
            if (isIncome)
            {
                worksheet.Cell(row, 4).Style.Font.FontColor = XLColor.Green;
                totalIncome += amount;
            }
            else
            {
                worksheet.Cell(row, 4).Style.Font.FontColor = XLColor.Red;
                totalExpense += amount;
            }

            // Number format for amount
            worksheet.Cell(row, 4).Style.NumberFormat.Format = "#,##0";
            
            row++;
        }

        // Summary section
        row += 2;
        worksheet.Cell(row, 1).Value = "TỔNG KẾT";
        worksheet.Cell(row, 1).Style.Font.Bold = true;
        worksheet.Range(row, 1, row, 6).Style.Fill.BackgroundColor = XLColor.LightGray;

        row++;
        worksheet.Cell(row, 1).Value = "Tổng thu nhập:";
        worksheet.Cell(row, 2).Value = totalIncome;
        worksheet.Cell(row, 2).Style.Font.FontColor = XLColor.Green;
        worksheet.Cell(row, 2).Style.NumberFormat.Format = "#,##0 ₫";
        worksheet.Cell(row, 2).Style.Font.Bold = true;

        row++;
        worksheet.Cell(row, 1).Value = "Tổng chi tiêu:";
        worksheet.Cell(row, 2).Value = totalExpense;
        worksheet.Cell(row, 2).Style.Font.FontColor = XLColor.Red;
        worksheet.Cell(row, 2).Style.NumberFormat.Format = "#,##0 ₫";
        worksheet.Cell(row, 2).Style.Font.Bold = true;

        row++;
        worksheet.Cell(row, 1).Value = "Số dư:";
        worksheet.Cell(row, 2).Value = totalIncome - totalExpense;
        worksheet.Cell(row, 2).Style.Font.FontColor = (totalIncome - totalExpense) >= 0 ? XLColor.Green : XLColor.Red;
        worksheet.Cell(row, 2).Style.NumberFormat.Format = "#,##0 ₫";
        worksheet.Cell(row, 2).Style.Font.Bold = true;

        row++;
        if (startDate.HasValue && endDate.HasValue)
        {
            worksheet.Cell(row, 1).Value = $"Kỳ báo cáo: {startDate.Value:dd/MM/yyyy} - {endDate.Value:dd/MM/yyyy}";
            worksheet.Cell(row, 1).Style.Font.Italic = true;
        }

        // Auto-fit columns
        worksheet.Columns().AdjustToContents();

        // Add borders
        var dataRange = worksheet.RangeUsed();
        dataRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        dataRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;

        // Return as byte array
        using var stream = new MemoryStream();
        workbook.SaveAs(stream);
        return stream.ToArray();
    }

    private static string GenerateCsv(List<Domain.Entities.Transaction> transactions)
    {
        var sb = new StringBuilder();
        sb.AppendLine("Ngày,Danh mục,Loại,Số tiền,Ghi chú,Ví");
        foreach (var t in transactions)
        {
            var type = t.Category?.Type == CategoryType.Income ? "Thu nhập" : "Chi tiêu";
            var amount = t.Category?.Type == CategoryType.Income ? t.Amount : -t.Amount;
            var note = t.Note?.Replace(",", ";").Replace("\n", " ") ?? "";
            sb.AppendLine($"{t.TransactionDate:dd/MM/yyyy},{t.Category?.Name},{type},{amount},{note},{t.Wallet?.Name}");
        }
        return sb.ToString();
    }
}
