# AG Live — Blueprint

अलग ऐप और अलग सर्वर। होम पर तीन दरवाजे हैं: लाइव कैमरा, फोटो जाँच, और चैट व आवाज़। टाइप चैट पहले OpenAI की है। लाइव आवाज़ और वीडियो Gemini 3.8 Live की हैं।

## 1. पूरा सिस्टम

```mermaid
flowchart LR
  Phone["Android app<br/>AG Live"]
  Web["AG Live website"]
  API["Node API<br/>ag-live-api"]
  FB["Firebase<br/>Auth, database, storage"]
  Gemini["Google Gemini Live"]
  OpenAI["OpenAI<br/>AG Expert chat and photo"]
  Weather["Weather"]

  Phone --> API
  Web --> API
  API --> FB
  API --> OpenAI
  API --> Weather
  Phone -->|"voice and video token"| Gemini
  API -->|"live token"| Gemini
```

AG Farmer का Razorpay और जानकारी-लेख वाला बोलने वाला बटन इस ऐप के सर्वर पर नहीं है। दोनों ऐप एक ही मशीन पर अलग प्रोसेस में चलते हैं। एक को रीस्टार्ट करने से दूसरा नहीं रुकता।

## 2. ऐप की स्क्रीन

```mermaid
flowchart TB
  Login["Login / register / Google"]
  Home["Home"]
  Camera["Live camera video"]
  Photo["Photo check"]
  Hub["Chat and voice hub"]
  Voice["Voice call"]
  Plans["Subscription"]
  Profile["Profile"]
  Credit["Credit token"]

  Login --> Home
  Home --> Camera
  Home --> Photo
  Home --> Hub
  Hub --> Voice
  Home --> Plans
  Home --> Profile
  Profile --> Credit
```

होम के तीन बड़े कार्ड: लाइव कैमरा, फोटो जाँच, चैट और आवाज़।

## 3. चैट और फोटो

```mermaid
sequenceDiagram
  participant Farmer
  participant App
  participant API
  participant Memory
  participant OpenAI

  Farmer->>App: चैट या पत्ती की फोटो
  App->>API: chat
  API->>Memory: इस यूजर की पुरानी बात
  API->>OpenAI: AG Expert
  OpenAI-->>API: जवाब
  API->>Memory: सेव
  API-->>App: टेक्स्ट
  App-->>Farmer: चैट हब
```

चैट का पहला मॉडल OpenAI है। Gemini चैट भी सर्वर पर मौजूद है, पर डिफॉल्ट AG Expert है।

## 4. आवाज़ और वीडियो

```mermaid
sequenceDiagram
  participant Farmer
  participant App
  participant API
  participant Gemini

  Farmer->>App: आवाज़ या लाइव कैमरा
  App->>API: live session
  API-->>App: छोटा टोकन
  App->>Gemini: आवाज़, वीडियो में फोटो भी
  Gemini-->>App: आवाज़ वापस
  App-->>Farmer: सुनाए और लिखे
```

वीडियो कॉल लॉग-इन यूजर को सुपर प्लान माँगती है। गेस्ट को एक मुफ्त वीडियो ट्रायल मिलता है।

## 5. सर्वर के मुख्य हिस्से

```mermaid
flowchart TB
  Route["POST action router"]
  Auth["Login, OTP, Google"]
  Chat["Chat via OpenAI"]
  Live["Gemini Live token"]
  Quota["Plan limits"]
  Context["Per-user chat memory"]
  Photo["Photo check"]
  Support["Support"]
  Store["Firebase"]

  Route --> Auth
  Route --> Chat
  Route --> Live
  Route --> Photo
  Route --> Support
  Chat --> Quota
  Chat --> Context
  Live --> Store
  Auth --> Store
  Context --> Store
```

डेटा Firebase पर यूजर की अपनी जगह में रहता है: `users/{uid}/ai` और ईमेल वाली कॉपी। चैट की खिड़की नाम वाले सेशन में रहती है। कोर्स की बात फसल के थ्रेड में रहती है।
