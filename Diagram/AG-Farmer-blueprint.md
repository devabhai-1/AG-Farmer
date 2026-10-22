# AG Farmer — Blueprint

किसान ऐप। पैकेज `com.agfarmer.app`. आवाज़ और वीडियो **Gemini 3.8 Live** से चलते हैं। टाइप चैट Gemini और OpenAI दोनों से चल सकती है। पैसा Razorpay से बनता है।

## 1. पूरा सिस्टम

```mermaid
flowchart LR
  Phone["Android app<br/>AG Farmer"]
  Web["Website<br/>ag-farmer.com"]
  Admin["Admin panel"]
  API["Node API<br/>api.ag-farmer.com"]
  FB["Firebase<br/>Auth, database, storage"]
  Gemini["Google Gemini<br/>chat + Live voice"]
  OpenAI["OpenAI<br/>chat, photo, article voice"]
  Pay["Razorpay"]
  Weather["Weather"]

  Phone --> API
  Web --> API
  Admin --> API
  API --> FB
  API --> Gemini
  API --> OpenAI
  API --> Pay
  API --> Weather
  Phone -->|"live voice and video<br/>short token only"| Gemini
```

ऐप कभी API की असली चाबी नहीं रखता। चाबी सिर्फ सर्वर पर रहती है। लाइव कॉल के लिए सर्वर एक छोटा टोकन देता है, फोन उसी से Google से जुड़ता है।

## 2. ऐप की स्क्रीन

```mermaid
flowchart TB
  Login["Login / OTP / Google"]
  Shell["Main shell"]
  Home["Home"]
  Chat["Chat"]
  Course["Crop course"]
  Jankari["Jankari"]
  Profile["Profile"]
  Plans["Subscription"]
  Voice["AG Live voice"]
  Video["Treatment video call"]

  Login --> Shell
  Shell --> Home
  Shell --> Chat
  Shell --> Course
  Shell --> Jankari
  Shell --> Profile
  Home --> Plans
  Chat --> Voice
  Chat --> Video
  Course --> Voice
  Profile --> Plans
```

नीचे पाँच टैब हैं: होम, चैट, कोर्स, जानकारी, प्रोफाइल।

## 3. चैट का रास्ता

```mermaid
sequenceDiagram
  participant Farmer
  participant App
  participant API
  participant Memory
  participant Model

  Farmer->>App: सवाल या पत्ती की फोटो
  App->>API: action chat
  API->>Memory: प्लान के हिसाब से पुरानी चैट
  API->>Model: Gemini या OpenAI
  Model-->>API: पूरा जवाब
  API->>Memory: यह सवाल और जवाब सेव
  API-->>App: टेक्स्ट
  App-->>Farmer: चैट में दिखाओ
```

याद रखने की सीमा:

| प्लान | पुरानी चैट |
| --- | --- |
| ₹299 | 5 |
| ₹599 | 10 |
| ₹2,650 | 30 |
| ₹13,500 | 300 |

एक चैट का मतलब किसान का सवाल और उसका जवाब। फ्री और पुराना ₹99 प्लान पुरानी चैट याद नहीं रखते।

## 4. AG Live आवाज़

```mermaid
sequenceDiagram
  participant Farmer
  participant App
  participant API
  participant Gemini

  Farmer->>App: AG Live खोले
  App->>API: voice session
  API-->>App: छोटा टोकन + सेटअप
  App->>Gemini: आवाज़ भेजे
  Gemini-->>App: आवाज़ वापस
  App-->>Farmer: बोले और ऊपर लिखे
```

जवाब में वजह, बीघा और लीटर-पंप की मात्रा, समय, तरीका और एक सावधानी आती है। “कृषि विशेषज्ञ से पूछ लें” बोलकर नहीं आता। वह लाइन कॉल काटने वाले बटन के ऊपर लिखी रहती है।

वीडियो कॉल भी यही Live मॉडल है। फर्क यह है कि कैमरे की फोटो भी साथ जाती है। पहली लाइन फसल की तरफ कैमरा करने को कहती है।

## 5. पेमेंट

```mermaid
flowchart LR
  App["Subscription screen"]
  API["API"]
  Razorpay["Razorpay"]
  User["Firebase user plan"]

  App -->|"order"| API
  API --> Razorpay
  Razorpay -->|"paid"| API
  API --> User
  User -->|"plan open"| App
```

Razorpay की सीक्रेट चाबी सिर्फ सर्वर पर है। सफल पेमेंट के बाद ही प्लान खुलता है।

## 6. सर्वर के मुख्य हिस्से

```mermaid
flowchart TB
  Route["One POST action router"]
  Auth["Login, OTP, Google"]
  Chat["Chat"]
  Live["Gemini Live token"]
  Quota["Daily limits"]
  Context["Chat memory"]
  Course["Crop course"]
  Know["Jankari articles"]
  Pay["Razorpay"]
  Store["Firebase"]

  Route --> Auth
  Route --> Chat
  Route --> Live
  Route --> Course
  Route --> Know
  Route --> Pay
  Chat --> Quota
  Chat --> Context
  Live --> Context
  Auth --> Store
  Context --> Store
  Pay --> Store
```

जानकारी वाले लेख की “बोलें” आवाज़ OpenAI की है, Gemini Live की नहीं।
