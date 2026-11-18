export function Phone({ screen, priority = false, gallery = false, children }) {
  const base = process.env.NEXT_PUBLIC_BASE_PATH || "";
  return (
    <div className="phone">
      <div className={gallery ? "phone-screen-stack" : undefined}>
        {(gallery ? screens : [screen]).map((frame) => (
          <img
            key={frame.file}
            src={`${base}/screens/${frame.file}.png`}
            alt={frame.alt}
            aria-hidden={frame.file !== screen.file || undefined}
            width="390"
            height="844"
            loading={priority ? "eager" : "lazy"}
            fetchPriority={priority ? "high" : undefined}
            decoding="async"
          />
        ))}
      </div>
      {children}
    </div>
  );
}

export const screens = [
  {
    file: "check-in",
    label: "Photo check-in",
    title: "Photo, location, time.",
    description:
      "Submit a photo from the selected office. P Attendance records the time and captures location when you check in.",
    alt: "P Attendance home with an office selector, round check-in button, and attendance summary.",
  },
  {
    file: "history",
    label: "Personal history",
    title: "Your attendance, day by day.",
    description:
      "See today’s status, your streak, and a dated record of past check-ins in one place.",
    alt: "Dark-theme History screen with a monthly overview and dated check-ins using sample data.",
  },
  {
    file: "offices",
    label: "Office admin",
    title: "A roster for each office.",
    description:
      "See who has checked in, set attendance windows, and review evidence for offices you administer.",
    alt: "Admin dashboard with example team members, check-in totals, and an attendance window.",
  },
];
