"use client";

import * as React from "react";

interface CameraVideoProps extends Omit<React.VideoHTMLAttributes<HTMLVideoElement>, "ref"> {
  stream: MediaStream | null;
}

// Attaches a MediaStream to a video element imperatively — srcObject cannot be
// set as a JSX prop so we use a ref + effect instead.
export function CameraVideo({ stream, ...props }: CameraVideoProps) {
  const ref = React.useRef<HTMLVideoElement | null>(null);

  React.useEffect(() => {
    const el = ref.current;
    if (el) el.srcObject = stream;
  }, [stream]);

  return <video ref={ref} {...props} />;
}
