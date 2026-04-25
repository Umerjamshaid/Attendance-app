# 🎓 Flutter Learning Journey

Since you're starting out, here are the absolute best resources to understand how to build professional, scalable apps like this one.

---

## 🏗️ 1. Architecture & Patterns (Separation of Concerns)
This is the most important part of your current project.

- **Clean Architecture in Flutter** (Reso Coder)
  - [Clean Architecture Playlist](https://www.youtube.com/playlist?list=PLB6lc7nQ1n4iYGE_khpXRdJkJQH9Z7MIm)
  - *Why?* This explains why we have `Data`, `Domain`, and `Presentation` layers.

- **The Provider Pattern** (Official State Management)
  - [Provider Package Guide](https://docs.flutter.dev/data-and-backend/state-management/options#provider)
  - [Simple Provider Tutorial (Net Ninja)](https://www.youtube.com/watch?v=8II1VPfbFfQ&list=PL4cUxeGkcL9jLYyp2Aoh6hcWuxFDX6PBJ)

---

## 📱 2. UI & Design
To master those animations and clean layouts you saw in the `testui.dart`:

- **Flutter Widget of the Week**
  - [Official Playlist](https://www.youtube.com/playlist?list=PLjxrf2q8roU23XGwz3Km7sQZFTdB996iG)
  - Short, 2-minute videos on every Flutter widget.

- **Responsive Design in Flutter**
  - [Guide to Responsive UI](https://docs.flutter.dev/ui/layout/responsive)

---

## 📡 3. Working with APIs & Backend
- **Networking in Flutter** (Http package)
  - [Fetching Data over Internet](https://docs.flutter.dev/cookbook/networking/fetch-data)

---

## 🛠️ 4. Tools for you
- **FastAPI Documentation** (For your mock API)
  - [FastAPI Tutorial](https://fastapi.tiangolo.com/tutorial/)

---

## 🚀 Pro Tip:
In your `PLANNING/structure.md` file, look at the **Data Flow** section again. 
1. **Service** talks to the API.
2. **Provider** talks to the Service.
3. **Screen** talks to the Provider.

**Never let the Screen talk to the API directly!** 🛑
