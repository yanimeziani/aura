import Image from 'next/image';

type LogoProps = {
  className?: string;
  priority?: boolean;
  adaptive?: boolean;
};

export default function Logo({
  className = 'h-8 w-auto',
  priority = false,
  adaptive = true,
}: LogoProps) {
  return (
    <Image
      src="/dragun-logo.svg"
      alt="Dragun"
      width={200}
      height={50}
      className={`${className} ${adaptive ? 'dark:invert' : ''}`}
      priority={priority}
    />
  );
}
