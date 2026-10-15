// Sends one mail through Scaleway Transactional Email's HTTP API (specs/10 §4, Q41):
//   POST https://api.scaleway.com/transactional-email/v1alpha1/regions/{region}/emails
//   header X-Auth-Token: <secret key>, body { from, to, subject, text, html, project_id }
// The answer is 2xx with an `emails` array (the mail is queued; it is not yet delivered).
//
// The fetch is injected so the tests pass a fake. Errors carry a short code and an HTTP
// status and never the address, the code or the provider's response body, so whatever the
// hook logs or returns to GoTrue cannot leak them.

export const SCALEWAY_API = "https://api.scaleway.com";
export const SEND_TIMEOUT_MS = 15_000;

export interface ScalewayConfig {
  secretKey: string;
  projectId: string;
  region: string;
  fromEmail: string;
  fromName: string;
}

export interface OutgoingMail {
  to: string;
  subject: string;
  text: string;
  html: string;
}

export type MailSendErrorCode =
  | "provider_timeout"
  | "provider_unreachable"
  | "provider_rejected";

export class MailSendError extends Error {
  constructor(
    readonly code: MailSendErrorCode,
    /** The HTTP status the hook returns to GoTrue for this failure. */
    readonly status: number,
    /** The provider's status when it answered; null when it did not. */
    readonly providerStatus: number | null = null,
  ) {
    super(code);
    this.name = "MailSendError";
  }
}

const REGION = /^[a-z]{2}-[a-z]{3}$/;

export function emailsUrl(region: string): string {
  if (!REGION.test(region)) {
    throw new Error("SCW_REGION must look like fr-par");
  }
  return `${SCALEWAY_API}/transactional-email/v1alpha1/regions/${region}/emails`;
}

/** The request body Scaleway expects, from the public API reference. */
export function emailBody(
  config: ScalewayConfig,
  mail: OutgoingMail,
): Record<string, unknown> {
  return {
    from: { email: config.fromEmail, name: config.fromName },
    to: [{ email: mail.to }],
    subject: mail.subject,
    text: mail.text,
    html: mail.html,
    project_id: config.projectId,
  };
}

export async function sendScalewayMail(
  config: ScalewayConfig,
  mail: OutgoingMail,
  options: { fetch?: typeof fetch; timeoutMs?: number } = {},
): Promise<void> {
  const doFetch = options.fetch ?? fetch;
  let response: Response;
  try {
    response = await doFetch(emailsUrl(config.region), {
      method: "POST",
      headers: {
        "X-Auth-Token": config.secretKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(emailBody(config, mail)),
      signal: AbortSignal.timeout(options.timeoutMs ?? SEND_TIMEOUT_MS),
    });
  } catch (err) {
    if (
      err instanceof Error &&
      (err.name === "TimeoutError" || err.name === "AbortError")
    ) {
      throw new MailSendError("provider_timeout", 504);
    }
    throw new MailSendError("provider_unreachable", 502);
  }

  // The body is not read: on failure it may echo the request, and nothing here needs it.
  await response.body?.cancel();
  if (response.status < 200 || response.status > 299) {
    throw new MailSendError("provider_rejected", 502, response.status);
  }
}
