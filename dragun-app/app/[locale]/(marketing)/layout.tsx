import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';

export default function MarketingLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-base-100 text-base-content">
      <Navbar />
      {children}
      <Footer />
    </div>
  );
}
