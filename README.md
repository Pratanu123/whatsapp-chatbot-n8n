# WhatsApp AI Support Bot for n8n

An n8n workflow for a WhatsApp customer-support assistant. It receives messages through Meta's WhatsApp Cloud API, uses an AI Agent to understand the request, and looks up FAQs, orders, and support tickets in Supabase Postgres. It can also create a support ticket and send the answer back on WhatsApp.

The workflow export contains no API keys or database passwords. You must create and select credentials in your own n8n instance before activating it.

## Features

- WhatsApp message trigger and reply through Meta's WhatsApp Cloud API.
- FAQ search against business-provided answers.
- Order lookup, scoped to the sender's phone number.
- Support-ticket creation and customer-scoped ticket status/listing.
- Postgres-backed chat memory keyed by the WhatsApp sender.
- OpenRouter chat model with an OpenAI chat-model fallback.
- Docker Compose deployment with persistent n8n data.

## Architecture

```text
Customer
  │ WhatsApp message
  ▼
Meta WhatsApp Cloud API
  │ HTTPS webhook
  ▼
n8n WhatsApp Trigger → Edit Fields → AI Agent → Send message
                                │
                                ├── OpenRouter Chat Model (primary)
                                ├── OpenAI Chat Model (fallback)
                                ├── Postgres Chat Memory (conversation history)
                                └── Postgres tools → Supabase Postgres
                                      ├── GetFAQs
                                      ├── GetOrderStatus
                                      ├── CreateSupportTicket
                                      ├── GetMyTickets
                                      └── GetTicketStatus
```

The workflow is imported inactive. n8n stores its configuration and credentials in the `n8n_data` Docker volume. Customer data and business records live in Supabase; chat history is stored by the Postgres Chat Memory node.

## Requirements

- Docker Desktop (or Docker Engine) with the Docker Compose plugin.
- An n8n instance reachable at `http://localhost:5678` for local setup.
- A Meta developer app with the WhatsApp product and a WhatsApp Business account/phone number.
- A Supabase project with its Postgres database available to the n8n host.
- API credentials for OpenRouter and OpenAI, if using both configured model nodes.

## Install and start n8n

From this repository's directory:

```sh
docker compose up -d
docker compose logs -f n8n
```

Open [http://localhost:5678](http://localhost:5678) and complete n8n's initial owner setup. The Compose file persists n8n data in the named `n8n_data` volume, so a normal container restart does not remove workflows or credentials.

Useful commands:

```sh
docker compose ps
docker compose logs -f n8n
docker compose stop
docker compose start
docker compose down
```

`docker compose down` keeps the named data volume. Do not use `docker compose down -v` unless you intend to delete that volume and all locally stored n8n data.

For a production deployment, use a stable HTTPS domain and a reverse proxy/tunnel configured for n8n webhooks. Set n8n's public webhook URL (`WEBHOOK_URL`) and proxy settings in the deployment environment as appropriate. Do not expose the n8n editor or a development tunnel publicly without appropriate access controls.

## Configure Supabase

1. Create a Supabase project and open **SQL Editor**.
2. Run the schema in [`supabase/schema.sql`](./supabase/schema.sql).
3. Add your actual FAQ records, order records, and any existing support tickets. The schema creates the tables but intentionally includes no sample customer data.
4. In Supabase's database settings, obtain a Postgres connection method reachable from the machine/container running n8n. Use the session pooler when direct database connections are not reachable from your network.
5. In n8n, create a **Postgres** credential for that database. Enter the host, port, database name, username, and password from Supabase; enable SSL/require SSL when offered.
6. Assign that credential to the workflow's Postgres Chat Memory node and all five Postgres tools: `GetFAQs`, `GetOrderStatus`, `CreateSupportTicket`, `GetMyTickets`, and `GetTicketStatus`.

The SQL is designed for the workflow's exact queries:

- `faqs`: `question`, `answer`, and a text-array `keywords` field.
- `orders`: `order_number`, `customer_phone`, `status`, and optional `expected_delivery`.
- `support_tickets`: generated `ticket_number`, `customer_phone`, `issue`, `status`, and `created_at`.

Store phone numbers in a consistent international format (including country code, such as `+1...`). Order numbers can be stored with or without the `ORD-` prefix; the workflow normalizes that prefix when searching. Populate FAQs with verified business policies and answers; the assistant is instructed not to invent business facts.

The Postgres Chat Memory node uses the WhatsApp sender ID as its session key and the schema creates its `n8n_chat_histories` table. Use the same database credential for the memory node and workflow tools, or grant the memory credential access to that table and its sequence. Do not use a Supabase `service_role` key as a database password. Keep database credentials private, grant only the permissions the workflow needs, and do not expose these tables through public Supabase APIs.

## Configure Meta WhatsApp Cloud API

1. In the [Meta for Developers](https://developers.facebook.com/) dashboard, create or select an app and add the **WhatsApp** product.
2. Connect a WhatsApp Business account and phone number. A Meta test phone number is suitable for initial testing; add the intended recipient to the test recipients.
3. In n8n, create the WhatsApp credentials required by both workflow nodes:
   - **WhatsApp OAuth account** for the **WhatsApp Trigger**.
   - **WhatsApp account** for the **Send message** node.

   Provide the values requested by the n8n credential form from your Meta app/WhatsApp setup. Do not place access tokens or app secrets in the workflow JSON or commit them to Git.
4. Make the n8n webhook reachable by Meta over HTTPS. For local development, use a trusted HTTPS tunnel; for production, use a stable HTTPS endpoint and configure n8n's public webhook URL.
5. In the Meta app's WhatsApp webhook configuration, complete webhook verification and subscribe the WhatsApp Business Account to the `messages` webhook field. The n8n trigger must be active and reachable for Meta to deliver events.
6. After sending a test message from an authorized recipient, inspect the n8n execution. Verify that the trigger receives the sender's phone number and message before enabling the workflow for regular use.

Meta's test credentials/numbers and production access have different limits and review requirements. Follow the current setup and permissions shown in your Meta developer dashboard before moving the app to production.

## Configure AI model credentials

The AI Agent has two model connections:

- **Primary:** **OpenRouter Chat Model**, configured with `openrouter/free`.
- **Fallback:** **OpenAI Chat Model**, connected to the agent's fallback-model input.

Create the corresponding credentials in n8n and select them on the model nodes. Confirm that each model is available to your account and test both connections before activating the workflow. The exported workflow does not include credentials, so the fallback will not work until you configure it.

### Use another fallback model

You can use a different provider for the fallback, or use a second OpenRouter model:

1. Add the provider's n8n chat-model node (for example, OpenRouter, OpenAI, Anthropic, Google Gemini, or a locally hosted model supported by your n8n installation).
2. Configure its provider credentials and choose a model that supports the chat features required by the AI Agent. With OpenRouter, choose a model identifier available to your OpenRouter account; `openrouter/free` is the current primary model in this export.
3. Connect the new model node to the AI Agent's **Fallback Model** input, replacing the OpenAI connection if desired. Keep your primary model connected to the primary language-model input.
4. Test normal requests and the fallback path in n8n's execution view. Check provider availability, rate limits, and model compatibility; a fallback is useful only if its credentials and provider are independently available.

The fallback is an alternate model connection in the n8n workflow. It is not automatically configured just by selecting a model in OpenRouter, and model availability or names may change. If you do not want a fallback, adjust the AI Agent's fallback settings and model connections intentionally.

## Import and activate the workflow

1. In n8n, choose **Workflows → Import from File** and select [`workflows/whatsapp-ai-support-bot.json`](./workflows/whatsapp-ai-support-bot.json).
2. Open the imported workflow. Resolve the credentials on both WhatsApp nodes, the model nodes, the Postgres Chat Memory node, and each Postgres tool.
3. Confirm that the Supabase tables are populated and that the Meta webhook is reachable over HTTPS.
4. Save, activate the workflow, and send a test WhatsApp message.
5. Check n8n's execution view and the Supabase tables if a lookup or ticket operation does not behave as expected.

The exported workflow has been made inactive and stripped of instance-specific IDs and credential IDs. Credentials are not included; select your own credentials after import.

## How to use

Once active, customers can message the connected WhatsApp number to:

- Ask business FAQs (matched against `faqs`).
- Check an order using its order number (matched against `orders` and the sender's phone number).
- Ask about their support tickets or select a ticket to check its status.
- Report an issue or explicitly request follow-up to create a support ticket.

The workflow's agent instructions constrain replies to customer support, match the customer's language, and require tool results for business facts. Keep your FAQs and order data current; AI-generated replies are not a substitute for testing the workflow and reviewing business policies.

## Security and operations

- Never commit Meta tokens, OpenRouter/OpenAI keys, Supabase passwords, or n8n encryption keys.
- The Compose file contains no application secrets. n8n encrypts stored credentials using its instance encryption key; preserve the `n8n_data` volume and back up your n8n encryption key securely.
- A Supabase database password was previously present in a local Compose-file comment and has been removed. Rotate that password before connecting this deployment.
- Use HTTPS for public webhooks and protect access to the n8n editor.
- Back up both the Supabase data and the n8n volume. The volume contains workflows and encrypted credentials.
- Review the workflow and test with non-production data before enabling it for real customers.

## Repository layout

```text
.
├── docker-compose.yml
├── workflows/
│   └── whatsapp-ai-support-bot.json
└── supabase/
    └── schema.sql
```
