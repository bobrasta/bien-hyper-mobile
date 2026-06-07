# Hypermed — Demo Guide

Hypermed is a Windows desktop application for managing medical equipment across hospitals in Tanzania. It covers machine tracking, service tickets, inventory, revenue, staff coordination, and customer relationships — all connected live to a central cloud server.

---

## Getting Started

### Launching the App

Double-click **hypermed.exe**. The app connects to the Hypermed cloud server automatically. No installation or configuration needed.

---

## Demo Login Accounts

All accounts use the same password: **`password`**

| Name | Email | Role | Access |
|------|-------|------|--------|
| Admin User | admin@hypermed.tz | Admin | Full access to everything |
| Amina Rashid | amina@hypermed.tz | Sales | Dashboard, Machines, Sales, Customers, Email, Staff, Reports, Settings |
| Bernard Lyimo | bernard@hypermed.tz | Finance | Dashboard, Revenue, Staff, Reports, Settings |
| James Mollel | james@hypermed.tz | Technician | Dashboard, Machines, Hospitals, Service, Inventory, Staff, Reports, Settings |
| Fatuma Hassan | fatuma@hypermed.tz | Customer Service | Dashboard, Customers, Service, Email, Staff, Reports, Settings |

> **Recommended for demo:** Start with **Admin User** to show all features, then switch to other roles to show access control.

---

## Screens — Detailed Guide

---

### 1. Login Screen

> 📸 *[Screenshot: Login screen with logo and email/password fields]*

The login screen is the first thing users see when they open the app. It features:

- The **Hypermed logo** centered at the top
- An **email address field** and a **password field**
- A **Login** button that authenticates against the central server
- An error message appears below the button if the credentials are wrong (e.g. "Invalid email or password")
- If the server is unreachable, the app shows "Cannot reach the server. Check your connection."

**What to show:**
- Type `admin@hypermed.tz` and `password` then click Login
- The app transitions immediately into the main shell once authenticated
- Point out that login is instant because the server is cloud-hosted

---

### 2. Dashboard

> 📸 *[Screenshot: Full dashboard with KPI cards at top and content below]*

The dashboard is the home screen visible to all roles. It gives a live summary of the entire operation at a glance.

#### KPI Cards (top row)
Four coloured cards across the top of the screen:
- **Total Machines** — total number of medical devices tracked across all hospitals
- **Operational** — how many machines are currently working (green)
- **Open Tickets** — number of service tickets currently open or in progress (blue)
- **Overdue Tickets** — tickets that have passed their due date without resolution (red)

> 📸 *[Screenshot: KPI card row — four coloured cards]*

#### Revenue This Month
A highlighted figure showing total revenue collected in the current calendar month from paid and partially paid invoices.

#### Recent Service Tickets
A list of the 5 most recently created service tickets, each showing:
- Ticket reference number
- Machine name and hospital
- Status badge (Open / In Progress / Overdue / Completed)
- Assigned technician name
- Time since creation

> 📸 *[Screenshot: Recent tickets list]*

#### Top Hospitals by Revenue
A ranked list of the top 5 highest-revenue hospitals this month, showing hospital name, short code, and monthly revenue figure in TZS.

> 📸 *[Screenshot: Top hospitals list]*

**What to show:**
- Point out that all numbers update live from the database — no manual refresh needed
- Hover over a recent ticket to highlight it; click to navigate directly to that ticket's detail

---

### 3. Machines

> 📸 *[Screenshot: Machines list with filter chips at top]*

The machines screen manages all medical equipment in the field.

#### Machine List
The main view is a list/table of all machines showing:
- Machine name and model
- Equipment type (Ventilator, Dialysis Machine, X-Ray Unit, Ultrasound, ECG, Defibrillator, etc.)
- Assigned hospital
- Current status with a colour-coded badge:
  - 🟢 **Operational** — working normally
  - 🟡 **Under Service** — currently being serviced
  - 🔴 **Decommissioned** — retired from use
- Serial number

> 📸 *[Screenshot: Machine list rows with status badges]*

#### Filter Chips (top bar)
A row of filter chips to narrow the list:
- **All** — shows every machine
- **Operational** — working machines only
- **Under Service** — machines currently being serviced
- **Decommissioned** — retired machines
- Additional dropdowns to filter by **Hospital** and **Equipment Type**

A **search bar** lets users find a specific machine by name, model, or serial number. The list paginates with a **Load More** button at the bottom for large data sets.

> 📸 *[Screenshot: Filter chips with "Under Service" selected]*

#### Machine Detail Panel
Clicking any machine opens a detail panel on the right side of the screen (the list stays visible on the left). The detail panel has tabs:

**Overview tab:**
- Full machine name, model, manufacturer, serial number
- Hospital assignment, ward/department, installation date
- Current status with a change-status button
- Quick action buttons: **Log Service**, **Raise Ticket**, **Edit Machine**

> 📸 *[Screenshot: Machine detail overview tab]*

**Service History tab:**
- Timeline of all past service events for this machine
- Each entry shows: date, technician name, service type, duration, and notes

> 📸 *[Screenshot: Service history tab with timeline]*

**Revenue tab:**
- Total revenue generated by this machine
- Monthly breakdown chart

**Specifications tab:**
- Technical specs (voltage, weight, dimensions, warranty expiry, etc.) as entered by the admin

**What to show:**
- Filter to "Under Service" — this immediately shows only machines currently being worked on
- Click a machine to open its detail panel without leaving the list
- Click "Raise Ticket" to show how a service ticket can be created directly from a machine
- Click "Edit Machine" to show the edit dialog with all fields

---

### 4. Hospitals

> 📸 *[Screenshot: Hospitals list with cards]*

The hospitals screen manages all client facilities across Tanzania.

#### Hospital Cards / List
Each hospital entry shows:
- Hospital name and short code (e.g. MNH, KCMC, BMC)
- Type badge: **Public** / **Private** / **Mission**
- Region and district
- Machine count: total machines and how many are operational (e.g. "10 / 12 operational")
- Monthly revenue in TZS
- Primary contact name and phone number

> 📸 *[Screenshot: Hospital card showing machine count and revenue]*

#### Filter and Search
- Search bar to find a hospital by name or region
- Filter by hospital type (Public / Private / Mission)
- Filter by region (Dar es Salaam, Arusha, Mwanza, Dodoma, etc.)

#### Map View
A tab at the top switches to a **Tanzania map view**. Hospital locations are shown as pins on the map with their short codes. Clicking a pin shows a summary popup.

> 📸 *[Screenshot: Tanzania map with hospital pins]*

#### Add / Edit Hospital
An **Add Hospital** button opens a dialog with all fields: name, short code, type, region, district, GPS coordinates, contact details. Existing hospitals have an **Edit** button.

> 📸 *[Screenshot: Add/Edit hospital dialog]*

**What to show:**
- Switch between list and map view
- Click a hospital pin on the map to show its summary
- Open the edit dialog to show all the data fields that are managed

---

### 5. Service Tickets

> 📸 *[Screenshot: Service tickets list with status tabs]*

The service tickets screen is the core operational workflow for field technicians.

#### Ticket List
Shows all service tickets with:
- Ticket number (e.g. TKT-0001)
- Machine name and hospital
- Problem description (first line)
- Priority badge: **Low / Medium / High / Critical**
- Status badge: **Open / In Progress / Overdue / Completed**
- Assigned technician name and avatar
- Date created and days open

> 📸 *[Screenshot: Ticket list with colour-coded status badges]*

#### Status Filter Tabs
Tabs at the top filter tickets by status:
- **All** — every ticket regardless of status
- **Open** — newly created, not yet assigned or started
- **In Progress** — technician is actively working on it
- **Overdue** — past due date without resolution
- **Completed** — resolved and closed

> 📸 *[Screenshot: "Overdue" tab selected showing red-highlighted tickets]*

#### Ticket Detail Panel
Clicking a ticket opens its full detail on the right side:

**Header:**
- Ticket number, created date, last updated
- Machine name (clickable — goes to machine detail)
- Hospital name
- Priority and status badges
- Assigned technician with avatar

> 📸 *[Screenshot: Ticket detail header]*

**Problem Description:**
- Full description of the reported issue
- Expected resolution date

**Checklist:**
- A step-by-step checklist of tasks to complete for this ticket
- Each item has a checkbox — technicians tick items off as they work
- Progress bar shows overall completion percentage

> 📸 *[Screenshot: Ticket checklist with progress bar]*

**Parts Used:**
- List of spare parts consumed during the repair
- Each part shows: SKU, name, quantity used, unit cost, total cost
- An **Add Part** button opens a picker to select from inventory

> 📸 *[Screenshot: Parts used section]*

**Attachments:**
- File attachments (photos, PDFs, reports) uploaded by technicians
- Each file shows name, size, and upload date
- Click to open a file; an **Upload** button adds new files from the computer

> 📸 *[Screenshot: Attachments section with uploaded files]*

**Resolution Notes:**
- Free-text field for the technician to describe what was done
- A **Mark as Resolved** button closes the ticket once notes are entered

#### New Ticket
A **+ New Ticket** button opens a creation dialog:
- Select machine (from live list)
- Describe the problem
- Set priority and expected resolution date
- Assign a technician

> 📸 *[Screenshot: New ticket dialog]*

#### CSV Export
A **Export** button at the top right exports the currently filtered ticket list as a CSV file to any folder on the computer.

**What to show:**
- Switch to the **Overdue** tab — shows tickets that need urgent attention, highlighted red
- Click one overdue ticket and walk through all the tabs: checklist, parts, attachments
- Show the **Add Part** button and how inventory is linked
- Click **Export** and save a CSV to the Desktop

---

### 6. Inventory

> 📸 *[Screenshot: Inventory table with low-stock row highlighted]*

The inventory screen manages all spare parts and consumables.

#### Inventory Table
A searchable table with columns:
- **SKU** — unique part code (e.g. VEN-FILTER-01)
- **Name** — part description
- **Category** — Machine Part / Consumable / Accessory / Equipment / Other
- **Unit** — Piece / Box / Litre / Set / kg / Roll
- **Stock Qty** — current quantity in stock
- **Reorder Level** — minimum quantity before restocking is needed
- **Unit Cost** — cost per unit in TZS
- **Supplier** — supplier name
- **Status** — Active / Inactive

> 📸 *[Screenshot: Full inventory table]*

#### Low-Stock Highlight
Any item where **Stock Qty ≤ Reorder Level** is highlighted in red/amber — immediately visible so the team knows what to order.

> 📸 *[Screenshot: Low-stock row highlighted in red]*

#### Adjust Stock
Clicking the **Adjust** button on any row opens a dialog to increase or decrease the stock quantity, with a note field to explain the reason (e.g. "Received from supplier" or "Used in TKT-0042").

> 📸 *[Screenshot: Adjust stock dialog]*

#### Add / Edit / Deactivate Items
- **Add Item** opens a form with all fields: SKU, name, category, unit, cost, reorder level, supplier
- **Edit** modifies an existing item
- **Deactivate** soft-deletes an item (it disappears from active list but data is retained)

#### Compatible Machine Models
Each part has a list of compatible machine models (e.g. "Mindray SV300, Hamilton C6") visible in the detail view.

#### CSV Export
The **Export** button downloads the full inventory table as a CSV file.

**What to show:**
- Point out the red low-stock items immediately — those are `DFB-PAD-01` (Defibrillator Pads, stock = 0)
- Click Adjust on any item and enter a quantity to demonstrate stock management
- Click Add Item and fill in fields to show the creation form
- Export to CSV

---

### 7. Sales Pipeline

> 📸 *[Screenshot: Kanban board with 5 columns]*

The sales pipeline screen shows the commercial side of the business — active deals with hospitals and procurement offices.

#### Kanban Board
Five columns represent the stages of a sale:
1. **Prospect** — initial contact, not yet qualified
2. **Qualified** — confirmed budget and need
3. **Proposal** — quote or tender submitted
4. **Negotiation** — terms being discussed
5. **Closed Won / Closed Lost** — deal finalised

Each card shows:
- Lead title (hospital name + equipment type)
- Assigned sales person
- Deal value in TZS
- Expected close date
- Days since last activity

> 📸 *[Screenshot: Kanban cards in multiple columns]*

**What to show:**
- Scroll across the columns to show the full pipeline
- Drag a card from **Proposal** to **Negotiation** to show status update
- Point out deal values in TZS

---

### 8. Revenue & Invoices

> 📸 *[Screenshot: Revenue screen with bar chart and invoice list]*

The revenue screen gives a complete financial picture of the business.

#### 12-Month Revenue Chart
A bar chart showing revenue collected each month for the past 12 months. The current month is highlighted. Amounts are in TZS.

> 📸 *[Screenshot: 12-month revenue bar chart]*

#### Revenue by Hospital
A ranked list of the top 10 hospitals by revenue, showing:
- Hospital name and short code
- Monthly revenue in TZS
- A horizontal bar indicating relative contribution

> 📸 *[Screenshot: Revenue by hospital list]*

#### Invoice List
A filterable table of all invoices:
- Invoice number
- Hospital name
- Machine associated
- Issue date and due date
- Total amount and amount paid
- Status badge: **Paid** (green) / **Partial** (amber) / **Pending** (blue) / **Overdue** (red)

> 📸 *[Screenshot: Invoice list with colour-coded status badges]*

#### Invoice Detail
Clicking an invoice opens a detail view showing all line items, payment history, and invoice metadata.

> 📸 *[Screenshot: Invoice detail view]*

**What to show:**
- Point out the 12-month chart and note which months had highest revenue
- Filter invoices to **Overdue** — highlight the ones needing follow-up
- Click an invoice to show full detail

---

### 9. Customers / Contacts

> 📸 *[Screenshot: Contacts list with search bar]*

The contacts screen is the CRM — managing relationships with hospital staff, procurement officers, and decision makers.

#### Contact List
Each contact card shows:
- Full name and job title
- Hospital or organisation
- Phone number and email address
- Region
- Last interaction date
- Next follow-up date (if scheduled)
- Type badge: **Customer / Prospect / Supplier / Partner**

> 📸 *[Screenshot: Contact cards with type badges]*

#### Search and Filter
- Search by name, email, or hospital
- Filter by contact type or region

#### Contact Detail
Clicking a contact opens a full detail panel:

**Profile section:**
- All contact fields: name, title, organisation, phone, email, region, notes
- An **Edit** button to update any field
- A **Send Email** button that opens the email composer pre-filled with this contact's address

> 📸 *[Screenshot: Contact profile panel]*

**Interaction Timeline:**
A vertical timeline of all past interactions with this contact, newest first. Each entry shows:
- Interaction type icon: 📞 Call / 📧 Email / 🏢 Visit / 💬 Meeting / 📋 Note
- Date and time
- Notes written during the interaction
- Next action date (if set)

> 📸 *[Screenshot: Interaction timeline]*

**Log Interaction button:**
Opens a dialog to record a new interaction:
- Select type (Call, Email, Visit, Meeting, Note)
- Write notes about what was discussed
- Optionally set a **Next Action Date** for follow-up

> 📸 *[Screenshot: Log interaction dialog]*

**Schedule Follow-up button:**
A quick date picker to set or update the next follow-up date without writing full interaction notes.

#### CSV Export
The **Export** button downloads the full contact list as CSV.

**What to show:**
- Click a contact to open the detail panel
- Show the interaction timeline and point out the type icons
- Click **Log Interaction**, fill in notes, and save to show CRM data entry
- Click **Send Email** to show how it pre-fills the email composer

---

### 10. Email

> 📸 *[Screenshot: Email inbox with message list on left and reading pane on right]*

The email screen is a built-in email client connected to the team's mailboxes via IMAP/SMTP.

#### Folder List (left sidebar)
- **Inbox** — incoming messages with unread count badge
- **Sent** — sent messages
- **Drafts** — unsent drafts

> 📸 *[Screenshot: Folder list with unread badge]*

#### Message List (centre column)
Each message in the list shows:
- Sender name and email
- Subject line
- First line of the message body
- Date and time
- Unread indicator (bold = unread, normal = read)
- Star/flag status

> 📸 *[Screenshot: Message list with unread messages in bold]*

#### Reading Pane (right side)
Clicking a message opens it in the reading pane:
- Full sender and recipient information
- Subject line
- Full message body (HTML emails are displayed cleanly)
- Date sent
- Attachment list (if any)

Action buttons:
- **Reply** — opens a compose window pre-filled with the reply address and quoted original
- **Reply All** — replies to all recipients
- **Forward** — forwards the message to a new address
- **Flag** — marks the message for follow-up
- **Delete** — removes the message

> 📸 *[Screenshot: Reading pane with reply button]*

#### Compose New Email
A **Compose** button at the top opens a full compose window:
- **To** field — type recipient address or name
- **Subject** field
- **Body** — plain text editor
- **Send** button — sends immediately via SMTP

> 📸 *[Screenshot: Compose email dialog]*

#### Sync
A **Sync** button pulls the latest messages from the mail server on demand (the app also checks periodically in the background).

**What to show:**
- Click Inbox to show incoming messages
- Open a message and click Reply to show the reply flow
- Click Compose and fill in a test email
- Point out the unread count badge in the folder list

---

### 11. Staff

> 📸 *[Screenshot: Staff screen showing team grid with availability badges]*

The staff screen gives a complete picture of who is on the team, what they are working on, and how to assign work.

#### Team Overview Grid
All staff are shown as cards, each displaying:
- Name and avatar/initials
- Role badge (Admin / Technician / Sales / Finance / CS)
- Region
- Availability status badge:
  - 🟢 **Available** — free to take new work
  - 🟡 **At Desk** — in office, can be assigned
  - 🔵 **Assigned** — has a task assigned but not started
  - 🔴 **On Task** — currently working on something

> 📸 *[Screenshot: Staff cards with availability badges]*

#### Filter Options
- Filter by **role** (show only Technicians, only Sales, etc.)
- Filter by **region** (Dar es Salaam, Arusha, Mwanza, etc.)
- Filter by **availability status**

#### Staff Detail / Task Panel
Clicking a staff member expands or opens a detail panel showing their current workload:
- **Active Ticket** — if they have a service ticket assigned, it shows here with machine, hospital, and status
- **General Tasks** — non-ticket tasks assigned to them (e.g. "Deliver equipment to KCMC", "Update asset register")
- Task timeline with due dates and status

> 📸 *[Screenshot: Staff member task panel]*

#### Task Filter Tabs
At the top of the task list, filter by:
- **All** — every task type
- **Open Tickets** — service tickets assigned to this person
- **In Progress** — tasks being worked on
- **Overdue** — past due date
- **Completed** — finished tasks
- **General** — non-ticket tasks

#### Assign / Create Tasks
- **Start Task** button on a ticket — marks the technician as active on that ticket
- **Resolve** button — marks the ticket complete from the staff view
- **+ New Task** button — opens a dialog to create a general task:
  - Task title and description
  - Category (pre-filled based on role: Technicians get "Maintenance", Sales get "Follow-up", etc.)
  - Due date (required)
  - Assign to a staff member

> 📸 *[Screenshot: New task dialog]*

#### CSV Export
The **Export** button downloads the staff list with their current status and task counts.

**What to show:**
- Point out the colour-coded availability badges on the cards
- Filter to "Technicians" only — shows only field staff
- Click a technician to show their active ticket and task list
- Click "+ New Task" and fill in the dialog

---

### 12. Reports

> 📸 *[Screenshot: Reports screen with KPI cards]*

The reports screen provides a high-level summary and is the starting point for management reporting.

#### KPI Summary Cards
Live figures shown as large cards:
- **Total Machines** — total equipment in the field
- **Open Tickets** — tickets currently open or in progress
- **Overdue Tickets** — tickets past their resolution date
- **Completed Tickets** — tickets resolved (all time)

> 📸 *[Screenshot: KPI cards row]*

#### Report Catalog
A grid of available report types (currently for display — full export reports are a future phase). Categories include:
- Equipment Reports
- Service Reports
- Financial Reports
- Staff Performance Reports

> 📸 *[Screenshot: Report catalog grid]*

**What to show:**
- Point out the live KPI numbers and note they match the Dashboard totals
- Show the report catalog and explain that detailed reports with date-range filtering are planned for the next phase

---

### 13. Notifications

> 📸 *[Screenshot: Notifications page with list of notification items]*

#### Bell Icon (Top Bar)
The bell icon in the top-right corner of every screen shows an unread count badge. This badge updates automatically every 20 seconds without requiring any refresh.

> 📸 *[Screenshot: Bell icon with red unread badge]*

#### Notification Dropdown
Clicking the bell opens a small dropdown panel showing the 10 most recent notifications. Each notification shows:
- An icon indicating the type (ticket, machine, system, invoice, etc.)
- The notification message
- Timestamp (e.g. "2 hours ago")
- Read / unread state (unread items have a coloured dot)

Action buttons in the dropdown:
- **Mark as Read** on individual items — tapping marks that notification read
- **Mark All Read** — clears all unread status at once
- **View all notifications** link at the bottom of the dropdown

> 📸 *[Screenshot: Notification dropdown panel]*

#### Full Notifications Page
Clicking **View all notifications** opens the dedicated notifications page showing all notifications with:
- Type-coloured icon (e.g. blue for tickets, amber for machines, green for invoices)
- Type label badge (e.g. "Ticket", "Machine", "System")
- Full notification message
- Exact timestamp
- Mark read / unread toggle per item
- **Mark All Read** button at the top

> 📸 *[Screenshot: Full notifications page]*

**What to show:**
- Point out the badge number on the bell
- Click the bell to open the dropdown
- Click a notification to mark it read (dot disappears)
- Click "View all notifications" to show the full page

---

### 14. Settings

> 📸 *[Screenshot: Settings screen with sidebar navigation on the left]*

Settings has six sections accessible from its own left sidebar.

---

#### Workspace

> 📸 *[Screenshot: Workspace settings tab]*

**Organisation Profile tab:**
- Company name, address, registration number, tax ID
- Primary contact phone and email
- Logo upload

**Team & Roles tab — 5 sub-tabs:**

- **Members** — full list of all staff accounts with their name, email, role, region, phone, and status (Active / Inactive). An **Invite** button sends a new user invitation.

> 📸 *[Screenshot: Team members list]*

- **Roles** — shows the permissions for each role (Admin, Manager, Technician, Sales, Finance, CS)

- **Pending** — any pending invitations waiting to be accepted

- **Activity** — audit log of who did what and when (login events, changes, etc.)

- **Settings** — organisation-wide settings

---

#### Billing

> 📸 *[Screenshot: Billing settings tab]*

- Current subscription plan name
- Billing cycle (monthly / annual)
- Next billing date
- Payment method on file
- Usage summary (number of users, machines, hospitals)

---

#### Communication

> 📸 *[Screenshot: Communication settings — email account configuration]*

- List of configured email accounts (IMAP/SMTP)
- Each account shows: email address, IMAP server, connection status (Connected / Error)
- **Add Account** button opens a dialog to enter: email address, IMAP host, IMAP port, SMTP host, SMTP port, username, password, encryption type
- **Test Connection** button verifies the IMAP connection before saving
- **Set as Default** — marks one account as the primary for outgoing mail

> 📸 *[Screenshot: Add email account dialog]*

---

#### Connections

> 📸 *[Screenshot: Connections tab]*

- API integration settings (webhooks, third-party connections)
- Currently configured integrations and their status

---

#### Security

> 📸 *[Screenshot: Security settings]*

- **Change Password** form — current password, new password, confirm new password
- **Active Sessions** — list of devices/sessions currently logged in with the ability to revoke

---

#### Preferences

> 📸 *[Screenshot: Preferences tab with theme selector]*

- **Theme** selector with three options:
  - **Dark** — dark background, light text (default)
  - **Light** — white background, dark text
  - **Neutral** — grey tone, works well in bright office environments
- Switching theme updates the entire app instantly without restart

> 📸 *[Screenshot: App in Light theme vs Dark theme side-by-side]*

---

## Role-Based Access Control

Each user role sees only the screens relevant to their work. The left sidebar automatically shows or hides screens based on the logged-in user's role. There is no way to access a hidden screen — navigation is fully enforced.

| Screen | Admin | Manager | Technician | Sales | Finance | CS |
|--------|:-----:|:-------:|:---------:|:-----:|:-------:|:--:|
| Dashboard | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Machines | ✓ | ✓ | ✓ | ✓ | — | — |
| Hospitals | ✓ | ✓ | ✓ | — | — | — |
| Service Tickets | ✓ | ✓ | ✓ | — | — | ✓ |
| Inventory | ✓ | ✓ | ✓ | — | — | — |
| Sales Pipeline | ✓ | ✓ | — | ✓ | — | — |
| Customers | ✓ | ✓ | — | ✓ | — | ✓ |
| Revenue | ✓ | ✓ | — | — | ✓ | — |
| Email | ✓ | ✓ | — | ✓ | — | ✓ |
| Staff | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Reports | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Settings | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

---

## Demo Data Reference

### Hospitals (10)
| Hospital | Code | Type | Region | Machines | Monthly Revenue |
|----------|------|------|--------|----------|-----------------|
| Muhimbili National Hospital | MNH | Public | Dar es Salaam | 12 (10 operational) | TZS 18,500,000 |
| Aga Khan Hospital Dar | AKH | Private | Dar es Salaam | 8 (8 operational) | TZS 14,200,000 |
| Kilimanjaro Christian Medical | KCMC | Mission | Kilimanjaro | 10 (9 operational) | TZS 12,800,000 |
| Bugando Medical Centre | BMC | Public | Mwanza | 9 (7 operational) | TZS 11,300,000 |
| Dodoma Regional Hospital | DRH | Public | Dodoma | 6 (5 operational) | TZS 8,200,000 |
| Mbeya Zonal Referral Hospital | MZRH | Public | Mbeya | 7 (6 operational) | TZS 9,600,000 |
| Arusha Lutheran Medical | ALMC | Mission | Arusha | 5 (5 operational) | TZS 7,400,000 |
| Mwananyamala Hospital | MWH | Public | Dar es Salaam | 4 (3 operational) | TZS 5,800,000 |
| Temeke Hospital | TMH | Public | Dar es Salaam | 4 (3 operational) | TZS 5,200,000 |
| Sekou Toure Hospital Mwanza | STH | Public | Mwanza | 5 (4 operational) | TZS 6,700,000 |

### Staff Accounts
| Name | Email | Role | Region |
|------|-------|------|--------|
| Admin User | admin@hypermed.tz | Admin | Dar es Salaam |
| James Mollel | james@hypermed.tz | Technician | Arusha |
| Grace Kimaro | grace@hypermed.tz | Technician | Mwanza |
| Peter Mwangi | peter@hypermed.tz | Technician | Dodoma |
| Emmanuel Shayo | emmanuel@hypermed.tz | Technician | Mbeya |
| Amina Rashid | amina@hypermed.tz | Sales | Dar es Salaam |
| Bernard Lyimo | bernard@hypermed.tz | Finance | Dar es Salaam |
| Fatuma Hassan | fatuma@hypermed.tz | Customer Service | Dar es Salaam |

### Inventory Items
| SKU | Item | Stock | Reorder Level |
|-----|------|-------|---------------|
| VEN-FILTER-01 | Ventilator HEPA Filter | 12 | 5 |
| DIA-CART-01 | Dialysate Bicarbonate Cartridge | 3 | 5 ⚠️ |
| XRY-TUBE-01 | X-Ray Tube Assembly | 1 | 1 |
| ULT-PROBE-01 | Ultrasound Convex Probe | 2 | 2 |
| ECG-LEADS-01 | ECG 12-Lead Cable Set | 8 | 3 |
| GEN-BATT-01 | UPS Battery Pack 12V 18Ah | 6 | 4 |
| VEN-CIRCUIT-01 | Ventilator Breathing Circuit | 20 | 10 |
| DFB-PAD-01 | Defibrillator Pads (pair) | 0 | 5 🔴 |

Items marked ⚠️ are below reorder level; 🔴 are completely out of stock.

---

## Suggested Demo Flow (15 minutes)

1. **(1 min)** Launch app → Login as `admin@hypermed.tz` / `password`
2. **(2 min)** Dashboard → walk through KPI cards, point out overdue tickets, show top hospitals
3. **(2 min)** Machines → filter to "Under Service" → click one machine → show detail panel tabs
4. **(2 min)** Service Tickets → go to "Overdue" tab → open a ticket → show checklist + parts used + attachments
5. **(1 min)** Inventory → point out the red out-of-stock row (DFB-PAD-01) → show Adjust Stock dialog
6. **(1 min)** Hospitals → switch to map view → click a hospital pin
7. **(1 min)** Staff → filter to Technicians → click a technician to show their active ticket
8. **(1 min)** Revenue → show 12-month bar chart → filter invoices to "Overdue"
9. **(1 min)** Contacts → click a contact → show interaction timeline → click Log Interaction
10. **(1 min)** Settings → Preferences → switch from Dark to Light theme live
11. **(1 min)** Logout → Login as `james@hypermed.tz` (Technician) → show the shorter sidebar
12. **(1 min)** Logout → Login as `bernard@hypermed.tz` (Finance) → show even more restricted sidebar

---

## App Notes

- All data is live from the Hypermed cloud server — no local database on the computer
- Changes made during the demo (new tickets, stock adjustments, logged interactions) are real and persist
- The notification bell badge refreshes automatically every 20 seconds in the background
- CSV export is available on Tickets, Inventory, and Contacts — saves directly to any folder
- The app supports Dark, Light, and Neutral themes — switchable from the top bar at any time
- If the app shows a connection error, check internet connectivity — the server is cloud-hosted on Railway
