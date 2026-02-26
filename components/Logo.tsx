import Image from 'next/image';

type LogoProps = {
  className?: string;
  priority?: boolean;
};

export default function Logo({ className = 'h-8 w-auto', priority = false }: LogoProps) {
  return (
    <Image
      src="/dragun-logo.svg"
      alt="Dragun"
      width={200}
      height={50}
      className={className}
      priority={priority}
    />
  );
}
