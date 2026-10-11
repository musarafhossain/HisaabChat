import env from '#start/env'
import { defineConfig, transports } from '@adonisjs/mail'

/**
 * Outgoing email (password reset codes). Gmail works with an app password:
 * SMTP_HOST=smtp.gmail.com, SMTP_PORT=587, SMTP_USERNAME=<gmail address>,
 * SMTP_PASSWORD=<16-letter app password>. When SMTP_HOST is empty the
 * server still starts; password reset then answers 503.
 */
const mailConfig = defineConfig({
  default: 'smtp',

  from: {
    address: env.get('MAIL_FROM_ADDRESS') ?? env.get('SMTP_USERNAME') ?? 'no-reply@localhost',
    name: env.get('MAIL_FROM_NAME') ?? 'HisaabChat',
  },

  mailers: {
    smtp: transports.smtp({
      host: env.get('SMTP_HOST') ?? 'localhost',
      port: env.get('SMTP_PORT') ?? 587,
      // 465 = TLS from the start; 587 = plain first, then upgraded with STARTTLS (required).
      secure: (env.get('SMTP_PORT') ?? 587) === 465,
      requireTLS: (env.get('SMTP_PORT') ?? 587) !== 465,
      auth: env.get('SMTP_USERNAME')
        ? {
            type: 'login',
            user: env.get('SMTP_USERNAME')!,
            pass: env.get('SMTP_PASSWORD')?.release() ?? '',
          }
        : undefined,
    }),
  },
})

/** Whether this server can send email (SMTP is configured). */
export const mailEnabled = Boolean(env.get('SMTP_HOST'))

export default mailConfig

declare module '@adonisjs/mail/types' {
  export interface MailersList extends InferMailers<typeof mailConfig> {}
}
