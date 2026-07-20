// Passkey (WebAuthn) ceremony helpers. The browser's native
// navigator.credentials API works directly with ArrayBuffers, but the Go
// backend (go-webauthn) sends/expects base64url strings for every binary
// field. These functions bridge the two — no third-party WebAuthn library
// needed, the platform API already covers it.
//
// The shapes below mirror go-webauthn's protocol.CredentialCreation /
// protocol.CredentialAssertion JSON exactly: the actual options always sit
// under a nested "publicKey" key (that's the wire format the WebAuthn spec
// itself defines for navigator.credentials.create/get), not flattened.

function base64urlToBuffer(value: string): ArrayBuffer {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
    value.length + ((4 - (value.length % 4)) % 4),
    "=",
  );
  const raw = atob(padded);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

function bufferToBase64url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let raw = "";
  for (const byte of bytes) raw += String.fromCharCode(byte);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// ── Registration (navigator.credentials.create) ──────────────────────────────

export function prepareCreationOptions(
  options: WebAuthnCreationOptions,
): CredentialCreationOptions {
  const pk = options.publicKey;
  return {
    // Note: CredentialCreationOptions has no "mediation" field — that only
    // applies to retrieval (.get()), not creation. go-webauthn still sends
    // one on the creation response; it's intentionally unused here.
    //
    // ponytail: cast bridges go-webauthn's plain-string enums (residentKey,
    // userVerification, attestation, transports) to the DOM lib's literal-union
    // types — same spec strings, no runtime risk, just a JSON-vs-buffer shape gap.
    publicKey: {
      ...pk,
      challenge: base64urlToBuffer(pk.challenge),
      user: { ...pk.user, id: base64urlToBuffer(pk.user.id) },
      excludeCredentials: pk.excludeCredentials?.map((c) => ({
        ...c,
        id: base64urlToBuffer(c.id),
      })),
    } as unknown as PublicKeyCredentialCreationOptions,
  };
}

export function serializeCreatedCredential(credential: PublicKeyCredential): unknown {
  const response = credential.response as AuthenticatorAttestationResponse;
  return {
    id: credential.id,
    rawId: bufferToBase64url(credential.rawId),
    type: credential.type,
    response: {
      clientDataJSON: bufferToBase64url(response.clientDataJSON),
      attestationObject: bufferToBase64url(response.attestationObject),
      transports: response.getTransports?.() ?? [],
    },
    authenticatorAttachment: credential.authenticatorAttachment ?? undefined,
    clientExtensionResults: credential.getClientExtensionResults(),
  };
}

// ── Login (navigator.credentials.get) ─────────────────────────────────────────

export function prepareRequestOptions(
  options: WebAuthnRequestOptions,
): CredentialRequestOptions {
  const pk = options.publicKey;
  return {
    mediation: options.mediation as CredentialMediationRequirement | undefined,
    // ponytail: see cast note in prepareCreationOptions above.
    publicKey: {
      ...pk,
      challenge: base64urlToBuffer(pk.challenge),
      allowCredentials: pk.allowCredentials?.map((c) => ({
        ...c,
        id: base64urlToBuffer(c.id),
      })),
    } as unknown as PublicKeyCredentialRequestOptions,
  };
}

export function serializeAssertedCredential(credential: PublicKeyCredential): unknown {
  const response = credential.response as AuthenticatorAssertionResponse;
  return {
    id: credential.id,
    rawId: bufferToBase64url(credential.rawId),
    type: credential.type,
    response: {
      clientDataJSON: bufferToBase64url(response.clientDataJSON),
      authenticatorData: bufferToBase64url(response.authenticatorData),
      signature: bufferToBase64url(response.signature),
      userHandle: response.userHandle ? bufferToBase64url(response.userHandle) : undefined,
    },
    authenticatorAttachment: credential.authenticatorAttachment ?? undefined,
    clientExtensionResults: credential.getClientExtensionResults(),
  };
}

export function passkeysSupported(): boolean {
  return typeof window !== "undefined" && "PublicKeyCredential" in window;
}

// ── Shapes matching the JSON go-webauthn sends (base64url strings, not buffers) ─
// Mirrors protocol.CredentialCreation: { publicKey: {...}, mediation? }

export interface WebAuthnCreationOptions {
  publicKey: {
    rp: { id?: string; name: string };
    user: { id: string; name: string; displayName: string };
    challenge: string;
    pubKeyCredParams: { type: "public-key"; alg: number }[];
    timeout?: number;
    excludeCredentials?: { id: string; type: "public-key"; transports?: string[] }[];
    authenticatorSelection?: {
      authenticatorAttachment?: string;
      residentKey?: string;
      requireResidentKey?: boolean;
      userVerification?: string;
    };
    attestation?: string;
  };
  mediation?: string;
}

// Mirrors protocol.CredentialAssertion: { publicKey: {...}, mediation? }
export interface WebAuthnRequestOptions {
  publicKey: {
    challenge: string;
    timeout?: number;
    rpId?: string;
    allowCredentials?: { id: string; type: "public-key"; transports?: string[] }[];
    userVerification?: string;
  };
  mediation?: string;
}
