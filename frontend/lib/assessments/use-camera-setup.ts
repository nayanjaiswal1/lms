"use client";

import * as React from "react";

export type PermissionStatus = "idle" | "requesting" | "granted" | "denied";

export interface UseCameraSetup {
  camera: PermissionStatus;
  microphone: PermissionStatus;
  phoneConnected: boolean;
  skipSecondary: boolean;
  stream: MediaStream | null;
  canProceed: boolean;
  requestPermissions: () => Promise<void>;
  setSkipSecondary: (v: boolean) => void;
  markPhoneConnected: () => void;
  stopStream: () => void;
}

interface CameraState {
  camera: PermissionStatus;
  microphone: PermissionStatus;
  phoneConnected: boolean;
  skipSecondary: boolean;
  stream: MediaStream | null;
}

export function useCameraSetup(requireCamera: boolean): UseCameraSetup {
  const [state, setState] = React.useState<CameraState>({
    camera: requireCamera ? "idle" : "granted",
    microphone: requireCamera ? "idle" : "granted",
    phoneConnected: false,
    skipSecondary: false,
    stream: null,
  });

  // Stable ref so the unmount cleanup always stops the latest stream
  const streamRef = React.useRef<MediaStream | null>(null);

  React.useEffect(() => {
    streamRef.current = state.stream;
  }, [state.stream]);

  React.useEffect(() => {
    return () => {
      streamRef.current?.getTracks().forEach((t) => t.stop());
    };
  }, []);

  // Check permission state on mount so "Blocked" is shown immediately without
  // requiring the user to click the button first. Skipped when camera is not required.
  React.useEffect(() => {
    if (!requireCamera || !navigator?.permissions) return;
    Promise.all([
      navigator.permissions.query({ name: "camera" as PermissionName }),
      navigator.permissions.query({ name: "microphone" as PermissionName }),
    ]).then(([cam, mic]) => {
      if (cam.state === "denied" || mic.state === "denied") {
        setState((prev) => ({ ...prev, camera: "denied", microphone: "denied" }));
      } else if (cam.state === "granted" && mic.state === "granted") {
        // Permissions already granted — get the stream without user needing to click
        void navigator.mediaDevices
          .getUserMedia({ video: true, audio: true })
          .then((stream) => {
            setState((prev) => ({ ...prev, camera: "granted", microphone: "granted", stream }));
          })
          .catch(() => {
            setState((prev) => ({ ...prev, camera: "denied", microphone: "denied" }));
          });
      }
    }).catch(() => undefined);
  }, [requireCamera]);

  const requestPermissions = React.useCallback(async () => {
    setState((prev) => ({ ...prev, camera: "requesting", microphone: "requesting" }));
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      setState((prev) => ({ ...prev, camera: "granted", microphone: "granted", stream }));
    } catch {
      setState((prev) => ({ ...prev, camera: "denied", microphone: "denied" }));
    }
  }, []);

  const setSkipSecondary = React.useCallback((v: boolean) => {
    setState((prev) => ({ ...prev, skipSecondary: v }));
  }, []);

  const markPhoneConnected = React.useCallback(() => {
    setState((prev) => ({ ...prev, phoneConnected: true }));
  }, []);

  const stopStream = React.useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    setState((prev) => ({ ...prev, stream: null }));
  }, []);

  return {
    ...state,
    canProceed: state.camera === "granted" && state.microphone === "granted",
    requestPermissions,
    setSkipSecondary,
    markPhoneConnected,
    stopStream,
  };
}
