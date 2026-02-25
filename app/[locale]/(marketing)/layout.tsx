import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-bg text-text-primary selection:bg-accent-emerald selection:text-bg">
      <Navbar />
      {children}
      <Footer />
    </div>
  );
}
