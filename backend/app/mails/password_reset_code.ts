import { BaseMail } from '@adonisjs/mail'

const escapeHtml = (text: string) =>
  text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')

/**
 * The 6-digit code for "Forgot password". Typed into the app, so it works
 * the same on Android, Windows and the web (no links to open).
 */
export default class PasswordResetCode extends BaseMail {
  constructor(
    private to: string,
    private name: string | null,
    readonly code: string,
    private minutes: number
  ) {
    super()
    this.subject = `${code} is your HisaabChat code`
  }

  prepare() {
    const hello = this.name ? `Hi ${this.name},` : 'Hi,'
    this.message.to(this.to)
    this.message.text(
      [
        hello,
        '',
        `Your code to reset your HisaabChat password is ${this.code}.`,
        `It works for ${this.minutes} minutes.`,
        '',
        "If you didn't ask for this, ignore this email: your password stays the same.",
      ].join('\n')
    )
    this.message.html(`<!doctype html>
<html><body style="margin:0;padding:24px;background:#F0F2F5;font-family:Roboto,'Segoe UI',Arial,sans-serif;color:#111B21">
  <div style="max-width:440px;margin:0 auto;background:#FFFFFF;border-radius:16px;padding:28px">
    <div style="font-size:20px;font-weight:700;color:#00897B">HisaabChat</div>
    <p style="font-size:15px;margin:20px 0 8px">${escapeHtml(hello)}</p>
    <p style="font-size:15px;margin:0 0 20px">Your code to reset your password is:</p>
    <div style="font-size:34px;font-weight:700;letter-spacing:8px;text-align:center;background:#E7F5F3;border-radius:12px;padding:16px 0">${this.code}</div>
    <p style="font-size:13px;color:#667781;margin:20px 0 0">It works for ${this.minutes} minutes. If you didn't ask for this, ignore this email: your password stays the same.</p>
  </div>
</body></html>`)
  }
}
