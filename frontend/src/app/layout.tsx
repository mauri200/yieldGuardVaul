import "./globals.css";
import Web3Provider from "../providers/Web3Provider";

export const metadata = {
  title: "YieldGuard",
  description: "AI Risk Managed Yield Vault",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es">
      <body>
        <Web3Provider>
          {children}
        </Web3Provider>
      </body>
    </html>
  );
}