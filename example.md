Using "Codebase"

Read [](file:///d%3A/An/Expense-management/Expense-management/services/ocr_service.py#1-1), lines 1 to 200

Searched for files matching `**/OCR*.md`, 2 matches

Searched for regex `ocr|OCR|extract_receipt|scan` (`**/*.py`), 32 results

Read [](file:///d%3A/An/Expense-management/Expense-management/services/ocr_service.py)

Read [](file:///d%3A/An/Expense-management/Expense-management/OCR_GUIDE.md#1-1), lines 1 to 100

Read [](file:///d%3A/An/Expense-management/Expense-management/OCR_SETUP.md)

Read [](file:///d%3A/An/Expense-management/Expense-management/services/ocr_service.py)

Read [](file:///d%3A/An/Expense-management/Expense-management/config.py#1-1), lines 1 to 50

Read [](file:///d%3A/An/Expense-management/Expense-management/services/ocr_service.py)

Searched for regex `extract_receipt|ocr|OCR` (`**/routes/*.py`), 8 results

Read [](file:///d%3A/An/Expense-management/Expense-management/services/ocr_service.py)

Read [](file:///d%3A/An/Expense-management/Expense-management/routes/transactions.py#175-175), lines 175 to 250

Tôi sẽ phân tích kỹ thuật OCR trong dự án này:

## 🔍 Kỹ Thuật OCR Trong Dự Án

### 📋 Tổng Quan

Dự án sử dụng **AI Vision API** để trích xuất thông tin từ ảnh hóa đơn, **KHÔNG** sử dụng OCR truyền thống (như Tesseract). Có 2 provider được hỗ trợ:

| Provider | Model | Chi phí | Khuyến nghị |
|----------|-------|---------|-------------|
| **Google Gemini** | `gemini-2.5-flash` | **MIỄN PHÍ** (60 req/phút) | ✅ Mặc định |
| **OpenAI** | `gpt-4o` | ~$0.01/ảnh | ⚠️ Trả phí |

---

### 🏗️ Kiến Trúc Code

```
services/
└── ocr_service.py
    ├── OCRService (Base class)
    ├── GeminiOCRService (Google Gemini)
    └── OpenAIOCRService (OpenAI GPT-4 Vision)
```

---

### 📝 Chi Tiết Kỹ Thuật

#### 1️⃣ **Base Class - `OCRService`**

```python
class OCRService:
    """Base OCR Service class"""
    
    def _validate_image(self, image_path):
        """Kiểm tra file ảnh hợp lệ"""
        # - Kiểm tra file tồn tại
        # - Giới hạn kích thước: MAX 20MB
        # - Định dạng: .jpg, .jpeg, .png, .gif, .bmp, .webp
    
    def _create_prompt(self):
        """Tạo prompt cho AI"""
        # Yêu cầu AI trả về JSON với format cố định
    
    def _validate_and_clean_data(self, data):
        """Validate và làm sạch dữ liệu trả về"""
```

#### 2️⃣ **Prompt Engineering**

```python
def _create_prompt(self):
    return """Trích xuất thông tin từ hóa đơn này theo JSON:
{
  "amount": <số tiền>,
  "date": "YYYY-MM-DD",
  "description": "<mô tả ngắn>",
  "merchant": "<tên cửa hàng>",
  "items": [{"name": "<tên>", "quantity": <số>, "price": <giá>}],
  "category_suggestion": "<Ăn uống|Di chuyển|Mua sắm|Y tế|Giải trí|Giáo dục|Khác>",
  "confidence": <0-1>
}
Lưu ý: Trả về null nếu không tìm thấy. Số tiền không có ký tự tiền tệ."""
```

#### 3️⃣ **Google Gemini Implementation**

```python
class GeminiOCRService(OCRService):
    def _initialize_client(self):
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        self.client = genai.GenerativeModel('gemini-2.5-flash')
    
    def extract_receipt_info(self, image_path):
        # 1. Load ảnh bằng PIL
        img = Image.open(image_path)
        
        # 2. Gửi ảnh + prompt tới Gemini
        response = self.client.generate_content([self._create_prompt(), img])
        
        # 3. Parse JSON response
        content = response.text.strip()
        extracted_data = json.loads(content)
        
        # 4. Validate và return
        return self._validate_and_clean_data(extracted_data)
```

#### 4️⃣ **OpenAI GPT-4 Vision Implementation**

```python
class OpenAIOCRService(OCRService):
    def _initialize_client(self):
        import openai
        self.client = openai.OpenAI(api_key=api_key)
    
    def _encode_image(self, image_path):
        """Encode ảnh sang base64"""
        with open(image_path, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')
    
    def extract_receipt_info(self, image_path):
        base64_image = self._encode_image(image_path)
        
        response = self.client.chat.completions.create(
            model='gpt-4o',
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": self._create_prompt()},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{base64_image}",
                            "detail": "high"  # Độ phân giải cao
                        }
                    }
                ]
            }],
            max_tokens=1000,
            temperature=0.1  # Giảm sáng tạo, tăng chính xác
        )
```

#### 5️⃣ **Factory Pattern**

```python
def get_ocr_service():
    """Factory function để chọn OCR provider"""
    provider = current_app.config.get('OCR_PROVIDER', 'gemini').lower()
    
    if provider == 'gemini':
        return GeminiOCRService()
    elif provider == 'openai':
        return OpenAIOCRService()
    else:
        return GeminiOCRService()  # Default
```

---

### 🔄 Flow Xử Lý

```
┌─────────────────┐
│  Upload ảnh     │
│  hóa đơn        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Validate ảnh   │
│  (size, format) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Lưu file tạm   │
│  (static/uploads)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Gọi AI API     │
│  (Gemini/OpenAI)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Parse JSON     │
│  response       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Validate &     │
│  Clean data     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Xóa file tạm   │
│  Return result  │
└─────────────────┘
```

---

### 📊 Dữ Liệu Trích Xuất

| Field | Type | Mô tả |
|-------|------|-------|
| `amount` | Float | Tổng tiền hóa đơn |
| `date` | String | Ngày giao dịch (YYYY-MM-DD) |
| `description` | String | Mô tả ngắn |
| `merchant` | String | Tên cửa hàng |
| `items` | Array | Danh sách sản phẩm |
| `category_suggestion` | String | Gợi ý danh mục |
| `confidence` | Float | Độ tin cậy (0-1) |

---

### ⚙️ Cấu Hình

**File `.env`:**
```env
# Chọn provider
OCR_PROVIDER=gemini

# Gemini (Miễn phí)
GEMINI_API_KEY=your-gemini-api-key

# OpenAI (Trả phí)
OPENAI_API_KEY=your-openai-api-key
```

**File config.py:**
```python
class Config:
    OCR_PROVIDER = os.environ.get('OCR_PROVIDER', 'gemini')
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
    OPENAI_API_KEY = os.environ.get('OPENAI_API_KEY')
    OPENAI_MODEL = 'gpt-4o'
```

---

### 🎯 Tóm Tắt

| Đặc điểm | Chi tiết |
|----------|----------|
| **Kỹ thuật** | AI Vision API (không phải OCR truyền thống) |
| **Provider mặc định** | Google Gemini 2.5 Flash |
| **Provider thay thế** | OpenAI GPT-4o Vision |
| **Input** | Ảnh hóa đơn (JPG, PNG, GIF, BMP, WEBP) |
| **Output** | JSON với thông tin giao dịch |
| **Giới hạn file** | 20MB |
| **Độ chính xác** | 90%+ (Gemini), 95%+ (OpenAI) |