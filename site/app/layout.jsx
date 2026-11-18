import localFont from "next/font/local";
import "lenis/dist/lenis.css";
import "./globals.css";

const dmSans = localFont({
  src: "./fonts/dm-sans.ttf",
  weight: "100 1000",
  variable: "--font-dm",
  display: "swap",
});

const basePath = process.env.NEXT_PUBLIC_BASE_PATH || "";
const title = "P Attendance | Photo check-ins for teams";
const description =
  "Check in with a photo and location, review your history, and manage attendance across your offices.";

export const metadata = {
  title,
  description,
  icons: { icon: `${basePath}/brand/icon.png` },
  openGraph: { title, description, type: "website", siteName: "P Attendance" },
};

export const viewport = { themeColor: "#142c26" };

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={dmSans.variable}>{children}</body>
    </html>
  );
}
