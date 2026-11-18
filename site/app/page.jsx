import { Fragment } from "react";
import {
  ArrowDown,
  ArrowUpRight,
  Camera,
  GitFork,
  MailPlus,
  Plus,
  ShieldCheck,
  Smartphone,
} from "lucide-react";
import { Motion } from "./motion";
import { Phone, screens } from "./phone";
import { Tour } from "./tour";

const repo = "https://github.com/Umerjamshaid/Attendance-app";
const base = process.env.NEXT_PUBLIC_BASE_PATH || "";
const approvedApk = process.env.ATTENDANCE_APK_URL;

function releaseUrl(raw) {
  if (!raw) return null;
  const url = new URL(raw);
  if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash) {
    throw new Error("ATTENDANCE_APK_URL must be a public HTTPS download URL with no credentials or query.");
  }
  if (!url.pathname.endsWith(".apk")) throw new Error("ATTENDANCE_APK_URL must point to an APK.");
  return url.href;
}

const apk = releaseUrl(approvedApk);

const steps = [
  {
    title: "Join your office",
    text: "Your office admin invites you. Sign in, then choose the office you’re checking in to.",
    icon: MailPlus,
  },
  {
    title: "Record a check-in",
    text: "Take a photo in the app. The time and location are recorded with your submission.",
    icon: Camera,
  },
  {
    title: "Review the record",
    text: "See your own history. Office admins can review their team’s check-ins and the associated evidence.",
    icon: ShieldCheck,
  },
];

const questions = [
  {
    question: "Can I try it without an office account?",
    answer: "Yes. Choose Explore demo on the sign-in screen. The demo uses sample data, does not request camera or location access, and does not submit check-ins.",
  },
  {
    question: "When is location collected?",
    answer: "The app requests location for a live check-in. This website does not request your location or access employee records.",
  },
  {
    question: "Who can see my check-in evidence?",
    answer: "Authorized admins can review check-in evidence for the office they manage. Office access is scoped to membership.",
  },
  {
    question: "Where can I get the app?",
    answer: "Android test builds and release notes are on GitHub. You can also build the demo from source. A live office account requires an invitation.",
  },
];

function Wordmark() {
  return (
    <a className="wordmark" href="#top" aria-label="P Attendance home">
      <img src={`${base}/brand/icon.png`} alt="" width="38" height="38" />
      <span>P Attendance</span>
    </a>
  );
}

function SectionTitle({ children }) {
  return (
    <h2 data-reveal aria-label={children}>
      {children.split(" ").map((word, index) => (
        <Fragment key={index}>
          {index > 0 ? " " : ""}
          <span aria-hidden="true">{word}</span>
        </Fragment>
      ))}
    </h2>
  );
}

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main">Skip to content</a>
      <div className="hero" id="top">
        <header className="wrap topbar">
          <Wordmark />
          <nav aria-label="Main navigation">
            <a className="nav-section" href="#features">Features</a>
            <a className="nav-section" href="#workflow">How it works</a>
            <a className="nav-download" href="#get">Get the app <ArrowDown size={16} aria-hidden="true" /></a>
          </nav>
        </header>
        <div className="wrap hero-copy">
          <h1 data-hero-title aria-label="P Attendance">
            <span aria-hidden="true">P</span>{" "}<span aria-hidden="true">Attendance</span>
          </h1>
          <p data-hero-copy>Photo check-ins and clear records for teams that work across offices.</p>
          <div className="actions hero-actions" data-hero-actions>
            <a className="button button-lime" href="#get">
              <Smartphone size={18} aria-hidden="true" /> Try on Android
            </a>
            <a className="button button-outline" href={repo}>
              <GitFork size={18} aria-hidden="true" /> View on GitHub
            </a>
          </div>
        </div>
        <div className="hero-stage" aria-hidden="true">
          <div className="hero-shot hero-shot-left"><Phone screen={screens[1]} /></div>
          <div className="hero-shot hero-shot-right"><Phone screen={screens[2]} /></div>
          <div className="hero-shot hero-shot-center"><Phone screen={screens[0]} priority /></div>
        </div>
      </div>
      <main id="main">
        <section id="features" className="feature-band">
          <div className="wrap">
            <div className="section-intro">
              <SectionTitle>From check-in to review.</SectionTitle>
              <p>Employees see their own records. Admins see the offices they manage.</p>
            </div>
            <Tour />
          </div>
        </section>
        <section id="workflow" className="workflow-band">
          <div className="wrap">
            <div className="section-intro">
              <SectionTitle>How it works.</SectionTitle>
            </div>
            <ol className="steps">
              {steps.map(({ title, text, icon: Icon }, index) => (
                <li key={title}>
                  <div className="step-mark"><Icon aria-hidden="true" size={26} /><span aria-hidden="true">0{index + 1}</span></div>
                  <h3>{title}</h3>
                  <p>{text}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>
        <section className="faq-band" id="questions">
          <div className="wrap faq-layout">
            <SectionTitle>Before you try it.</SectionTitle>
            <div>
              {questions.map(({ question, answer }) => (
                <details key={question}>
                  <summary>{question}<Plus size={21} aria-hidden="true" /></summary>
                  <p>{answer}</p>
                </details>
              ))}
            </div>
          </div>
        </section>
        <section id="get" className="get-band">
          <div className="wrap section-intro">
            <img className="get-mark" src={`${base}/brand/icon.png`} alt="" width="64" height="64" loading="lazy" />
            <SectionTitle>Try P Attendance.</SectionTitle>
            <p>Open the demo to look around, or ask your office admin for an invitation to check in for real.</p>
            <div className="actions">
              <a className="button button-forest" href={apk || `${repo}/releases`}>
                <Smartphone size={18} aria-hidden="true" /> {apk ? "Download Android APK" : "Browse Android releases"}
              </a>
              <a className="button button-paper" href={`${repo}#try-the-demo`}>
                Build the demo <ArrowUpRight size={18} aria-hidden="true" />
              </a>
            </div>
          </div>
        </section>
      </main>
      <footer className="footer">
        <div className="wrap footer-inner">
          <div>
            <Wordmark />
            <p>Built by <a href="https://github.com/Umerjamshaid">Umer Jamshaid</a>.</p>
          </div>
          <nav aria-label="Footer navigation">
            <a href={repo}>Source</a>
            <a href={`${repo}/issues`}>Report an issue</a>
            <a href="#questions">Questions</a>
          </nav>
        </div>
      </footer>
      <Motion />
    </>
  );
}
