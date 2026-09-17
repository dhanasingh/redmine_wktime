# ERPmine MCP
# Copyright (C) 2026-  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# ERPmine's REST endpoints, contributed to the redmine_mcp tool catalogue through
# the :redmine_mcp_register_tools hook. redmine_mcp discovers this class as a hook
# listener the moment init.rb requires the file — it needs no entry of its own —
# and the rows are inert when redmine_mcp is not installed.
#
# Each row is [tool_name, http_method, path, description] — what
# RedmineMcp::RestEndpoint expects. Add a row to expose another endpoint; no
# change to redmine_mcp is needed. Name tools after the business object, not the
# wk* controller: the model picks by name, so list_invoices beats wkinvoice_index.
#
# Only actions ERPmine marks with `accept_api_auth` can be listed — anything else
# answers 401/406. That attribute is inherited, and Rails view lookup walks the
# same chain, which is why several controllers here render a parent's template:
# quotes/purchase orders/supplier invoices/sales quotes use wkorderentity/*,
# supplier payments wkpaymententity/*, supplier accounts and contacts wkaccount/*
# and wkcontact/*, assets wkproductitem/*.
#
# ORDER: ERPmine's top-menu order (the wktime_menu map in redmine_wktime's
# init.rb) — Dashboards, Time & Expense, HR, CRM, Billing, Accounting,
# Purchasing, Inventory, Survey, Reports, Settings — then each entry's tab order,
# then the three groups with no menu entry of their own (material logs,
# self-service, lookups). Put a new row in its module's block, not at the bottom.
#
# GOTCHAS:
#   * list_loggable_projects, list_loggable_activities and
#     list_expensable_projects have no `.json` suffix on purpose: those actions
#     answer JSON only when no format is given, so `.json` raises 406. GET is safe
#     without it, but a POST would need it or CSRF rejects the request.
#   * export_report and export_invoice keep `.csv` (their actions have no JSON
#     block) and return raw text rather than parsed JSON. export_report MUST be
#     called with searchlist=wkreport: set_filter_session copies params into the
#     session only when that matches, or when api_request?, and `.csv` is not an
#     api_request? — without it every filter is silently ignored.
#
# WRITES: POST to a save-style action, never PUT, and no /:id in the path. The
# body is a FLAT object of top-level params, not {"invoice": {...}}. One action
# both creates and updates — omit the record's id to create — so create_*/update_*
# are two tools over one endpoint. Success returns an empty body, failures 422.
#
# Deliberately absent: deletes (#destroy, #delete_entries) and wkdevices#check,
# which registers a device against the caller as a side effect.
class ErpmineMcpHook < Redmine::Hook::Listener
  ENDPOINTS = [
    # --- Dashboards (wkdashboard) ---------------------------------------
    ['list_dashboard_graphs', :get, '/wkdashboard/get_graphs.json',
     'List the ERPmine dashboard graphs with their data and the caller\'s unseen-notification count. query: dashboard_type ("Emp" for the employee dashboard of leave balances and salary; omit it for the configured management graphs).'],
    ['get_dashboard_graph_detail', :get, '/wkdashboard/get_detail_report.json',
     'Get the drill-down rows behind one dashboard graph. query: gPath (the graph path from list_dashboard_graphs), dashboard_type, from, to, group_id, project_id.'],

    # --- Time & Expense — time (wktime) ---------------------------------
    ['list_timesheets', :get, '/wktime.json',
     'List ERPmine weekly timesheets with their hours and approval status. query: user_id (required, 0 for every user), period_type, period, from, to, group_id, project_id, filter_type, offset, limit. Never send status — it fails; filter the returned rows instead. Not the same as core list_time_entries — this is the ERPmine timesheet grid.'],
    ['get_timesheet', :get, '/wktime/edit.json',
     'Get one weekly timesheet with its editable time entries. query: user_id, startday (YYYY-MM-DD, the first day of the sheet period).'],
    ['create_timesheet_entries', :post, '/wktime/update.json',
     'Add time entries to a user\'s weekly timesheet. body {"user_id", "startday", "wktime_save": 1, "time_entries": [{"project": {"id"}, "issue": {"id"}, "activity": {"id"}, "spent_on", "hours", "comments"}]}. Every entry needs an activity — take its id from list_loggable_activities and stop with an error if that returns none. The user must be a member of the project — check list_project_memberships and stop with an error if they are not. Omit each entry\'s "id" to create it. Send "wktime_submit": 1 instead of "wktime_save" to submit the sheet for approval.'],
    ['update_timesheet_entries', :post, '/wktime/update.json',
     'Update time entries on an existing weekly timesheet. Same body as create_timesheet_entries, including the activity and project-membership rules, but each entry carries the "id" returned by get_timesheet. Entries omitted from the array are removed from the sheet, so send the full set of rows for the period.'],

    # --- Time & Expense — expense (wkexpense) ---------------------------
    ['list_expenses', :get, '/wkexpense.json',
     'List expense sheets with their amounts and approval status. query: user_id (required, 0 for every user), period_type, period, from, to, group_id, project_id, offset, limit. Never send status — it fails; filter the returned rows instead.'],
    ['get_expense', :get, '/wkexpense/edit.json',
     'Get one expense sheet with its editable expense entries. query: user_id, startday (YYYY-MM-DD, the first day of the sheet period).'],
    ['create_expense_entries', :post, '/wkexpense/update.json',
     'Add expense entries to a user\'s expense sheet. body {"user_id", "startday", "wktime_save": 1, "wk_expense_entries": [{"project": {"id"}, "issue": {"id"}, "activity": {"id"}, "spent_on", "amount", "comments"}]}. Every entry needs an activity — take its id from list_loggable_activities and stop with an error if that returns none. The user must be a member of the project — check list_project_memberships and stop with an error if they are not. Omit each entry\'s "id" to create it. Send "wktime_submit": 1 instead of "wktime_save" to submit the sheet for approval.'],
    ['update_expense_entries', :post, '/wkexpense/update.json',
     'Update expense entries on an existing expense sheet. Same body as create_expense_entries, including the activity and project-membership rules, but each entry carries the "id" returned by get_expense. Entries omitted from the array are removed from the sheet, so send the full set of rows for the period.'],

    # --- HR — employee master (wkuser) ----------------------------------
    ['list_employees', :get, '/wkuser.json',
     'List employees with their login, email, employee id, role, department, location, shift and joining date. query: name, group_id, status (1 active, 3 locked; "0" for every status), offset, limit. Requires the A_EMP permission — use get_my_erp_profile for the caller\'s own record.'],
    ['get_employee', :get, '/wkuser/:id/edit.json',
     'Get one employee\'s full master record: role, shift, location, department, billing rate, joining/birth/termination dates, emergency contact and bank/tax identifiers. The :id path parameter is the Redmine user id. Requires A_EMP. Employees are edited from the ERPmine UI — the REST API is read-only.'],

    # --- HR — leave balances (wkattendance) -----------------------------
    ['list_leave_balances', :get, '/wkattendance.json',
     'List per-user leave balances (balance, accrual and used hours for each leave type). query: status, group_id, name, accrual_on (YYYY-MM-DD, the accrual period end), offset, limit.'],
    ['get_leave_balance', :get, '/wkattendance/edit.json',
     'Get one user\'s leave balances for every leave type, with their editable balance/accrual/used hours. query: user_id, accrual_on (YYYY-MM-DD).'],
    ['create_leave_balance', :post, '/wkattendance/update.json',
     'Open leave balances for leave types a user does not have yet. body {"user_id", "accrual_on", "ids", "new_issue_ids", "balance_<leave_type_id>", "accrual_<leave_type_id>", "used_<leave_type_id>"} — new_issue_ids is a comma-separated list of leave-type ids, with one balance_/accrual_/used_ key per id in it. Both "ids" and "new_issue_ids" must be present; send an empty string for the unused one. user_id may not be the calling user.'],
    ['update_leave_balance', :post, '/wkattendance/update.json',
     'Update a user\'s existing leave balances. body {"user_id", "accrual_on", "ids", "new_issue_ids", "balance_<leave_type_id>", "accrual_<leave_type_id>", "used_<leave_type_id>"} — ids is a comma-separated list of leave-balance record ids from get_leave_balance. Both "ids" and "new_issue_ids" must be present; send an empty string for the unused one. user_id may not be the calling user.'],

    # --- HR — leave requests (wkleaverequest) ---------------------------
    ['list_leave_requests', :get, '/wkleaverequest.json',
     'List leave requests with their dates, leave type and approval status. query: user_id, group_id, leave_type, lveStatus, period_type, period, from, to, offset, limit.'],
    ['get_leave_request', :get, '/wkleaverequest/edit.json',
     'Get one leave request with its editable fields, plus the leave types and available leave hours for the requester. query: id.'],
    ['create_leave_request', :post, '/wkleaverequest/save.json',
     'Raise a leave request for the calling user. body {"leave_type_id", "start_date", "end_date", "leave_reasons", "submit_S": 1}. The submit_<status> key sets the status: submit_S submits it for approval, submit_N saves it as a draft.'],
    ['update_leave_request', :post, '/wkleaverequest/save.json',
     'Update or action an existing leave request. body {"lveReqID", "leave_type_id", "start_date", "end_date", "leave_reasons", "submit_S": 1}. Dates and type can only be changed while the request is a draft or rejected. Approvers action a submitted request with "submit_A" (approve) or "submit_R" (reject) plus "reviewer_comment".'],

    # --- HR — clock in/out (wkattendance) -------------------------------
    ['list_attendances', :get, '/wkattendance/clockindex.json',
     'List attendance (clock in / clock out) entries with their worked hours. query: period_type, period, from, to, user_id (0 for all users — send 0 unless one user is named; omitted means the caller only), group_id, show_on_map, offset, limit.'],
    ['get_attendance', :get, '/wkattendance/clockedit.json',
     'Get one user\'s attendance entries for a single day, with their editable clock-in/clock-out times. query: user_id, date (YYYY-MM-DD).'],
    ['create_attendance', :post, '/wkattendance/save_clock_in_out.json',
     'Clock a user in/out by adding attendance entries for a day. body {"user_id", "clock_entries": [{"clock_in": "YYYY-MM-DD HH:MM:SS", "clock_out": "YYYY-MM-DD HH:MM:SS"}]}. Omit each entry\'s "id" to create it; leave "clock_out" blank for an open (still clocked-in) entry. clock_in/clock_out are parsed as UTC and displayed in local time — subtract the user\'s UTC offset from the target local time.'],
    ['update_attendance', :post, '/wkattendance/save_clock_in_out.json',
     'Correct a user\'s existing attendance entries. Same body as create_attendance, but each entry carries the "id" returned by get_attendance. TIMEZONE RULE: Pass times in UTC by converting target local wall-clock time to UTC using the local timezone offset.'],

    # --- HR — payroll (wkpayroll) ---------------------------------------
    ['list_payrolls', :get, '/wkpayroll.json',
     'List payroll runs per user and period with their amounts and status. Defaults to the current month; for all time send period_type=2 with no from or to. query: period_type, period, from, to, group_id, user_id (0 for all users, omitted means the caller only), status, name, offset, limit.'],
    ['get_payroll', :get, '/wkpayroll/edit.json',
     'Get one user\'s payroll for a period, broken down into its salary components. query: user_id, salary_date (YYYY-MM-DD), isPreview (true to recompute the payroll without saving). Payroll is generated from the ERPmine UI — the REST API is read-only.'],

    # --- HR — shifts and scheduling (wkshift, wkscheduling) -------------
    ['list_shifts', :get, '/wkshift.json',
     'List the defined shifts with their start and end times and whether they are schedulable. query: offset, limit. Resolves shift_id for the scheduling and employee tools.'],
    ['get_shift_staffing', :get, '/wkshift/edit.json',
     'Get one shift\'s staffing rules — how many people of each role are required at a location and department. query: shift_id, location_id, department_id.'],
    ['list_shift_schedules', :get, '/wkscheduling.json',
     'List one month of shift schedules: who is rostered onto which shift on which day, plus the users\' own shift preferences. query: year, month, shift_id, day_off, department_id, location_id, user_id, group_id. Read-only — generating a roster writes rows and is only available from the ERPmine UI.'],

    # --- HR — skills (wkskill) ------------------------------------------
    ['list_skills', :get, '/wkskill.json',
     'List skill entries — who has which skill, at what rating, interest level, years of experience and when they last used it. query: skill_set (a skill-set enumeration id), group_id, user_id, rating, experience, interest_level, last_used (all four are minimum thresholds), project_id to list a project\'s skills instead of people\'s, offset, limit.'],
    ['get_skill', :get, '/wkskill/edit.json',
     'Get one skill entry with its rating, experience and skill-set options. query: id. Skills are recorded from the ERPmine UI — the REST API is read-only.'],

    # --- HR — referrals (wkreferrals) -----------------------------------
    ['list_referrals', :get, '/wkreferrals.json',
     'List employee referrals (candidates referred for hiring) with their status, referrer and graduation year. query: lead_name, status, location_id, pass_out, offset, limit.'],
    ['get_referral', :get, '/wkreferrals/edit.json',
     'Get one referral with its editable candidate fields and interview activities. query: lead_id.'],
    ['create_referral', :post, '/wkreferrals/update.json',
     'Refer a candidate. candidate_attributes is required on every call — send an empty object when there are no candidate details. body {"first_name", "last_name", "title", "description", "location_id", "referred_by", "status", "candidate_attributes": {"college", "degree", "pass_out"}, "address": [["email", "..."], ["work_phone", "..."]]}. status: N new, A assigned, IP in process, C converted (hired), RC recycled, L lost.'],
    ['update_referral', :post, '/wkreferrals/update.json',
     'Update a referral or move it through the hiring pipeline. body {"lead_id", ...same fields as create_referral}.'],

    # --- CRM — leads (wklead) -------------------------------------------
    ['list_leads', :get, '/wklead.json',
     'List CRM leads with their contact, company and status. query: lead_name, status, location_id, offset, limit.'],
    ['get_lead', :get, '/wklead/edit.json',
     'Get one CRM lead with its editable fields, address and related quotes. query: lead_id.'],
    ['create_lead', :post, '/wklead/update.json',
     'Create a CRM lead. body {"first_name", "last_name", "salutation", "title", "department", "description", "account_name", "account_number", "status", "opportunity_amount", "lead_source_id", "assigned_user_id", "location_id", "address": [["street", "..."], ["city", "..."]]}. status: N new, A assigned, IP in process, C converted, RC recycled, L lost.'],
    ['update_lead', :post, '/wklead/update.json',
     'Update a CRM lead or change its status (status codes: N new, A assigned, IP in process, C converted, RC recycled, L lost). body {"lead_id", ...same fields as create_lead}. Call get_lead first and re-submit every lead, contact and account field it returns — any field omitted is overwritten blank. To convert, set "status": "C" and pass "wklead_save_convert": 1 with those same fields.'],

    # --- CRM — accounts (wkcrmaccount) ----------------------------------
    ['list_crm_accounts', :get, '/wkcrmaccount.json',
     'List CRM accounts (customer/vendor companies). query: accountname, location_id, offset, limit.'],
    ['get_crm_account', :get, '/wkcrmaccount/edit.json',
     'Get one CRM account with its editable fields, address and related contacts. query: account_id.'],
    ['create_crm_account', :post, '/wkcrmaccount/update.json',
     'Create a CRM account. body {"account_name", "account_number", "account_category", "assigned_user_id", "description", "tax_number", "account_billing", "location_id", "address": [["street", "..."], ["city", "..."]]}.'],
    ['update_crm_account', :post, '/wkcrmaccount/update.json',
     'Update a CRM account. body {"account_id", ...same fields as create_crm_account}.'],

    # --- CRM — opportunities (wkopportunity) ----------------------------
    ['list_opportunities', :get, '/wkopportunity.json',
     'List CRM opportunities with their amount and sales stage. query: oppname, account_id, contact_id, sales_stage, period_type, period, from, to, offset, limit. Opportunities are created and edited from the ERPmine UI — the REST API is read-only.'],

    # --- CRM — activities (wkcrmactivity) -------------------------------
    ['list_crm_activities', :get, '/wkcrmactivity.json',
     'List CRM activities (calls, meetings, tasks). query: period_type, period, from, to, activity_type, status, assignee, related_to, show_on_map, offset, limit.'],
    ['get_crm_activity', :get, '/wkcrmactivity/edit.json',
     'Get one CRM activity with its editable fields. query: crm_activity_id.'],
    ['create_crm_activity', :post, '/wkcrmactivity/update.json',
     'Log a CRM activity. body {"activity_subject", "activity_type", "activity_status", "activity_description", "activity_start_date", "start_hour", "start_min", "activity_end_date", "end_hour", "end_min", "activity_duration", "activity_duration_min", "activity_direction", "location", "assigned_user_id", "related_to", "related_parent"}. activity_type: C call, M meeting, T task. activity_status: NS not started, IP in progress, C completed, PI pending input, D deferred. activity_direction (calls only): I inbound, O outbound. related_to: WkAccount, WkCrmContact, WkLead or WkOpportunity, with related_parent its record id.'],
    ['update_crm_activity', :post, '/wkcrmactivity/update.json',
     'Update a CRM activity. body {"crm_activity_id", ...same fields as create_crm_activity}.'],

    # --- CRM — contacts (wkcrmcontact) ----------------------------------
    ['list_crm_contacts', :get, '/wkcrmcontact.json',
     'List CRM contacts (people at an account). query: contactname, account_id, location_id, offset, limit.'],
    ['get_crm_contact', :get, '/wkcrmcontact/edit.json',
     'Get one CRM contact with its editable fields, address and related quotes. query: contact_id.'],
    ['create_crm_contact', :post, '/wkcrmcontact/update.json',
     'Create a CRM contact. body {"first_name", "last_name", "salutation", "contact_title", "department", "description", "assigned_user_id", "relationship_id", "location_id", "related_to": "WkAccount", "related_parent": <account id>, "address": [["street", "..."], ["city", "..."]]}. related_to is "WkAccount" to attach the contact to a company or "WkCrmContact" to attach it to another contact.'],
    ['update_crm_contact', :post, '/wkcrmcontact/update.json',
     'Update a CRM contact. body {"contact_id", ...same fields as create_crm_contact}.'],

    # --- CRM — sales quotes (wksalesquote) ------------------------------
    ['list_sales_quotes', :get, '/wksalesquote.json',
     'List sales quotes issued to customers and leads. query: period_type, period, from, to, account_id, contact_id, lead_id, project_id, offset, limit. Another WkInvoice type, so the rows look like list_invoices.'],
    ['get_sales_quote', :get, '/wksalesquote/edit.json',
     'Get one sales quote with its line items. query: invoice_id.'],
    ['create_sales_quote', :post, '/wksalesquote/update.json',
     'Issue a sales quote. body is the same shape as create_invoice — {"inv_date", "parent_type" ("WkAccount", "WkCrmContact" or "WkLead"), "parent_id", "inv_number", "field_status": "o", "description", "invoiceItems": {"1": {...}}}. original_currency is as in create_invoice.'],
    ['update_sales_quote', :post, '/wksalesquote/update.json',
     'Update a sales quote. body {"invoice_id", "saved_field_status", ...same fields as create_sales_quote, with each line carrying its "item_id"}. Send every line — omitted ones are deleted. original_currency cannot be changed on an existing line.'],

    # --- Billing — invoices (wkinvoice) ---------------------------------
    ['list_invoices', :get, '/wkinvoice.json',
     'List customer invoices with their number, date, amount and status. query: period_type, period, from, to, account_id, contact_id, project_id, lead_id, rfq_id, offset, limit.'],
    ['get_invoice', :get, '/wkinvoice/edit.json',
     'Get one invoice with its line items and editable fields. query: invoice_id.'],
    ['create_invoice', :post, '/wkinvoice/update.json',
     'Create an invoice. First call list_account_projects for the parent and put one of its project_id values on every line item; if it returns nothing, do not create the invoice. inv_start_date and inv_end_date are required — ask the caller for the period if they did not give one. Resolve parent_id with list_crm_accounts or list_crm_contacts; nothing is validated server-side. body {"inv_date", "inv_start_date", "inv_end_date", "parent_type": "WkAccount", "parent_id": <account id>, "inv_number", "field_status": "o", "description", "invoiceItems": {"1": {"name", "quantity", "rate", "item_type", "project_id", "original_currency"}}}. invoiceItems is keyed by row number starting at "1". original_currency is the same on every line: a value from list_expense_currencies, never an ISO code. Defaults to settings.wktime_currency. field_status: o open, c closed. item_type: i billable issue/time, e expense, m material, a asset, c credit.'],
    ['update_invoice', :post, '/wkinvoice/update.json',
     'Update an invoice. body {"invoice_id", "saved_field_status" (the status from get_invoice), "field_status", "inv_date", "inv_number", "description", "invoiceItems": {"1": {"item_id" (existing line id), "name", "quantity", "rate", "hd_item_type", "project_id"}}}. Line items omitted from invoiceItems are deleted, so send every row. original_currency cannot be changed on an existing line. An invoice that has payments or credit notes against it cannot be changed.'],
    ['export_invoice', :get, '/wkinvoice/export.csv',
     'Get one invoice as CSV — its header, the billed-to account and every line item, laid out as the printed invoice. query: invoice_id. Returns raw CSV text rather than JSON; use get_invoice when you need the fields as data.'],

    # --- Billing — payments (wkpayment) ---------------------------------
    ['list_payments', :get, '/wkpayment.json',
     'List payments received against invoices. query: period_type, period, from, to, account_id, contact_id, offset, limit.'],
    ['get_payment', :get, '/wkpayment/edit.json',
     'Get one payment with its allocations to invoices and editable fields. query: payment_id. Pass load_payment=true with related_to/related_parent instead to list an account\'s still-unpaid invoices when composing a new payment. Each row carries invoice_id and invoice_org_currency for create_payment.'],
    ['create_payment', :post, '/wkpayment/update.json',
     'Record a payment and allocate it across invoices. body {"payment_date", "payment_type_id", "reference_number", "description", "related_to": "WkAccount", "related_parent": <account id>, "tot_pay_amount", "payment_entries": [{"invoice_id", "amount", "invoice_org_currency"}]}. Take payment_type_id from list_crm_enumerations with enum_type=PT. Take invoice_id and invoice_org_currency from get_payment with load_payment=true — the invoice\'s own currency, not the base currency setting. related_parent is the account or contact id passed to that call, never an invoice id.'],
    ['update_payment', :post, '/wkpayment/update.json',
     'Update a payment and its invoice allocations. body {"payment_id", ...same fields as create_payment, with each payment_entries row carrying its "payment_item_id"}. Send every allocation row — an amount of 0 removes that allocation.'],

    # --- Billing — contracts (wkcontract) -------------------------------
    ['list_contracts', :get, '/wkcontract.json',
     'List billing contracts — the agreement that ties a customer account or contact to a project for a period. query: polymorphic_filter ("2" filter by contact, "3" by account, "1" by project only), contact_id, account_id, project_id, offset, limit.'],
    ['get_contract', :get, '/wkcontract/edit.json',
     'Get one contract with its parties, project, period and attachments. query: contract_id. Contracts are created and edited from the ERPmine UI — the REST API is read-only.'],

    # --- Accounting — transactions (wkgltransaction) --------------------
    ['list_gl_transactions', :get, '/wkgltransaction.json?summary_trans=days',
     'List general-ledger transactions with their type, date and amounts. query: period_type, period, from, to, trans_type, txn_ledger, summary_trans (days one row per transaction — the default when none is passed, week, month or year for period totals per ledger), offset, limit.'],
    ['get_gl_transaction', :get, '/wkgltransaction/edit.json',
     'Get one general-ledger transaction with its debit/credit detail lines. query: txn_id.'],
    ['create_gl_transaction', :post, '/wkgltransaction/update.json',
     'Post a general-ledger transaction. body {"txn_type", "date", "txn_cmt", "txntotalrow": 2, "txn_particular_1": <ledger id>, "txn_debit_1", "txn_credit_1", "txn_particular_2", "txn_debit_2", "txn_credit_2"} — one numbered set of keys per detail line, counted by txntotalrow. Each line carries either a debit or a credit, and total debits must equal total credits. txn_type: C contra, P payment, R receipt, J journal, S sales, PR purchase, CN credit note, DN debit note.'],
    ['update_gl_transaction', :post, '/wkgltransaction/update.json',
     'Update a general-ledger transaction. body {"gl_transaction_id", ...same fields as create_gl_transaction, with each detail line carrying its "txn_id_<n>"}. Detail lines omitted from the numbered keys are deleted, so send every line.'],

    # --- Accounting — chart of accounts (wkledger) ----------------------
    ['list_ledgers', :get, '/wkledger.json',
     'List the chart of accounts — every ledger with its type, opening balance and currency. query: ledger_type (A asset, L liability, I income, E expense, SY system), name, offset, limit. Resolves the ledger ids create_gl_transaction takes as txn_particular_<n>.'],
    ['get_ledger', :get, '/wkledger/edit.json',
     'Get one ledger with its type, opening balance and currency. query: ledger_id. Ledgers are created and edited from the ERPmine UI — the REST API is read-only.'],

    # --- Purchasing — RFQs (wkrfq) --------------------------------------
    ['list_rfqs', :get, '/wkrfq.json',
     'List requests for quotation with their period and open/closed status. query: rfq_name, rfq_date (YYYY-MM-DD, matches RFQs whose period covers that date), offset, limit.'],
    ['get_rfq', :get, '/wkrfq/edit.json',
     'Get one RFQ with its period, description and the supplier quotes raised against it. query: rfq_id. RFQs are created and edited from the ERPmine UI — the REST API is read-only.'],

    # --- Purchasing — supplier quotes (wkquote) -------------------------
    ['list_supplier_quotes', :get, '/wkquote.json',
     'List supplier quotes (a supplier\'s priced response to an RFQ) with their number, date, amount and status. query: period_type, period, from, to, account_id, contact_id, project_id, rfq_id, offset, limit.'],
    ['get_supplier_quote', :get, '/wkquote/edit.json',
     'Get one supplier quote with its line items. query: invoice_id.'],
    ['create_supplier_quote', :post, '/wkquote/update.json',
     'Create a supplier quote. rfq_id is required — take it from list_rfqs; without it the quote is linked to RFQ 0. inv_start_date and inv_end_date are required. Supplier is parent_type "WkAccount" with an id from list_supplier_accounts, or "WkCrmContact" from list_supplier_contacts — check it exists, nothing is validated server-side. body {"inv_date", "inv_start_date", "inv_end_date", "parent_type": "WkAccount", "parent_id": <supplier account id>, "inv_number", "field_status": "o", "description", "rfq_id", "invoiceItems": {"1": {"name", "quantity", "rate", "item_type", "project_id", "original_currency"}}}. original_currency, field_status and item_type are as in create_invoice.'],
    ['update_supplier_quote', :post, '/wkquote/update.json',
     'Update a supplier quote. body {"invoice_id", "saved_field_status", ...same fields as create_supplier_quote, with each line carrying its "item_id"}. Lines omitted from invoiceItems are deleted, so send every row. original_currency cannot be changed on an existing line.'],

    # --- Purchasing — purchase orders (wkpurchaseorder) -----------------
    ['list_purchase_orders', :get, '/wkpurchaseorder.json',
     'List purchase orders with their number, supplier, date, amount and status. query: period_type, period, from, to, account_id, contact_id, project_id, rfq_id, offset, limit.'],
    ['get_purchase_order', :get, '/wkpurchaseorder/edit.json',
     'Get one purchase order with its line items. query: invoice_id.'],
    ['create_purchase_order', :post, '/wkpurchaseorder/update.json',
     'Raise a purchase order, standalone or against a winning quote. body is the same shape as create_supplier_quote. invoiceItems is required — build the rows yourself; rfq_id and quote_id do not populate them over the API. original_currency is as in create_invoice. po_quote_id from list_supplier_quotes links a quote; omit it for a standalone order. inv_start_date and inv_end_date are required. Supplier is parent_type "WkAccount" with an id from list_supplier_accounts, or "WkCrmContact" from list_supplier_contacts — check it exists, nothing is validated server-side.'],
    ['update_purchase_order', :post, '/wkpurchaseorder/update.json',
     'Update a purchase order. body {"invoice_id", "saved_field_status", ...same fields as create_purchase_order, with each line carrying its "item_id"}. Send every line — omitted ones are deleted. original_currency cannot be changed on an existing line.'],

    # --- Purchasing — supplier invoices (wksupplierinvoice) -------------
    ['list_supplier_invoices', :get, '/wksupplierinvoice.json',
     'List supplier invoices (bills received from suppliers) with their number, date, amount and status. query: period_type, period, from, to, account_id, contact_id, project_id, rfq_id, offset, limit. Not the same as list_invoices, which is what you bill customers.'],
    ['get_supplier_invoice', :get, '/wksupplierinvoice/edit.json',
     'Get one supplier invoice with its line items. query: invoice_id.'],
    ['create_supplier_invoice', :post, '/wksupplierinvoice/update.json',
     'Record a supplier invoice, standalone or against a purchase order. body is the same shape as create_supplier_quote. invoiceItems is required — build the rows yourself; po_id does not populate them over the API. original_currency is as in create_invoice. si_inv_id from list_purchase_orders links an order; omit it for a standalone invoice. inv_start_date and inv_end_date are required. Supplier is parent_type "WkAccount" with an id from list_supplier_accounts, or "WkCrmContact" from list_supplier_contacts — check it exists, nothing is validated server-side.'],
    ['update_supplier_invoice', :post, '/wksupplierinvoice/update.json',
     'Update a supplier invoice. body {"invoice_id", "saved_field_status", ...same fields as create_supplier_invoice, with each line carrying its "item_id"}. Send every line — omitted ones are deleted. original_currency cannot be changed on an existing line.'],

    # --- Purchasing — supplier payments (wksupplierpayment) -------------
    ['list_supplier_payments', :get, '/wksupplierpayment.json',
     'List payments made to suppliers against their invoices. query: period_type, period, from, to, account_id, contact_id, offset, limit. The outbound counterpart of list_payments.'],
    ['get_supplier_payment', :get, '/wksupplierpayment/edit.json',
     'Get one supplier payment with its allocations to supplier invoices. query: payment_id. Pass load_payment=true with related_to/related_parent instead to list a supplier\'s still-unpaid invoices when composing a new payment. Each payment_entries row carries invoice_id (the id create_supplier_payment needs), invoice_no (display only), invoice_org_amount (the invoice total) and payment_org_amount (already paid); the outstanding balance is the difference.'],
    ['create_supplier_payment', :post, '/wksupplierpayment/update.json',
     'Pay a supplier and allocate it across their invoices. body {"payment_date", "payment_type_id", "reference_number", "description", "related_to": "WkAccount", "related_parent": <supplier account id>, "tot_pay_amount", "payment_entries": [{"invoice_id", "amount", "invoice_org_currency"}]}. Take payment_type_id from list_crm_enumerations with enum_type=PT. Take invoice_id and invoice_org_currency from get_supplier_payment with load_payment=true — invoice_id is that row\'s numeric id, never its invoice_no. Resolve every id before previewing the payment.'],
    ['update_supplier_payment', :post, '/wksupplierpayment/update.json',
     'Update a supplier payment and its allocations. body {"payment_id", ...same fields as create_supplier_payment, with each payment_entries row carrying its "payment_item_id"}. Send every allocation row — an amount of 0 removes that allocation.'],

    # --- Purchasing — supplier accounts (wksupplieraccount) -------------
    ['list_supplier_accounts', :get, '/wksupplieraccount.json',
     'List supplier companies. query: accountname, location_id, offset, limit. The supplier-side twin of list_crm_accounts — resolves parent_id/related_parent for the purchasing write tools.'],
    ['get_supplier_account', :get, '/wksupplieraccount/edit.json',
     'Get one supplier account with its editable fields and address. query: account_id.'],
    ['create_supplier_account', :post, '/wksupplieraccount/update.json',
     'Create a supplier account. body {"account_name", "account_number", "account_category", "assigned_user_id", "description", "tax_number", "account_billing", "location_id", "address": [["street", "..."], ["city", "..."]]}. Same shape as create_crm_account; the controller stamps account_type "S".'],
    ['update_supplier_account', :post, '/wksupplieraccount/update.json',
     'Update a supplier account. body {"account_id", ...same fields as create_supplier_account}.'],

    # --- Purchasing — supplier contacts (wksuppliercontact) -------------
    ['list_supplier_contacts', :get, '/wksuppliercontact.json',
     'List the people at supplier companies. query: contactname, account_id, location_id, offset, limit.'],
    ['get_supplier_contact', :get, '/wksuppliercontact/edit.json',
     'Get one supplier contact with its editable fields and address. query: contact_id.'],
    ['create_supplier_contact', :post, '/wksuppliercontact/update.json',
     'Create a supplier contact. body {"first_name", "last_name", "salutation", "contact_title", "department", "description", "assigned_user_id", "relationship_id", "location_id", "related_to": "WkAccount", "related_parent": <supplier account id>, "address": [["street", "..."], ["city", "..."]]}.'],
    ['update_supplier_contact', :post, '/wksuppliercontact/update.json',
     'Update a supplier contact. body {"contact_id", ...same fields as create_supplier_contact}.'],

    # --- Inventory — products (wkproduct) -------------------------------
    ['list_products_catalogue', :get, '/wkproduct.json',
     'List the product catalogue — the product definitions, not the stock on hand. query: name, category_id, offset, limit. For sellable/loggable stock use list_inventory_items; for the material-logging dropdowns use list_products.'],
    ['get_product', :get, '/wkproduct/edit.json',
     'Get one product with its category, unit of measure, attribute group, depreciation rate, applicable taxes, brands and models. query: product_id. Products are created and edited from the ERPmine UI — the REST API is read-only.'],

    # --- Inventory — stock items (wkproductitem) ------------------------
    ['list_inventory_items', :get, '/wkproductitem.json',
     'List stock on hand — every inventory item with its product, brand, model, serial number, location, quantity on hand and selling price. query: name, product_id, brand_id, location_id, project_id, available_items ("1" to show only items with stock left), offset, limit.'],
    ['get_inventory_item', :get, '/wkproductitem/edit.json',
     'Get one inventory item with its pricing, quantities, location and assembled components. query: inventory_item_id, or product_item_id to load the product-item side alone.'],
    ['create_inventory_item', :post, '/wkproductitem/update.json',
     'Add stock. body {"product_id", "brand_id", "product_model_id", "part_number", "product_attribute_id", "serial_number", "location_id", "project_id", "uom_id", "currency", "cost_price", "selling_price", "over_head_price", "available_quantity", "product_type": "I", "is_loggable"}. available_quantity is required; without it no stock is created and the call still returns 200. total_quantity is optional and defaults to available_quantity. Omit inventory_item_id to create. The response carries no id, so confirm with get_inventory_item.'],
    ['update_inventory_item', :post, '/wkproductitem/update.json',
     'Update a stock item. body {"inventory_item_id", "product_id", "brand_id", "product_model_id", "available_quantity", ...other fields from create_inventory_item}. Send product_id, brand_id and product_model_id exactly as get_inventory_item returns them, or a duplicate product item is created. Without available_quantity only selling_price and is_loggable are applied. Confirm the result with get_inventory_item.'],

    # --- Inventory — goods receipts (wkshipment) ------------------------
    ['list_shipments', :get, '/wkshipment.json',
     'List goods receipts — stock received from suppliers, with the serial number, supplier, date and value. query: period_type, period, from, to, polymorphic_filter ("2" by contact, "3" by account), contact_id, account_id, project_id, offset, limit.'],
    ['get_shipment', :get, '/wkshipment/edit.json',
     'Get one goods receipt with each received line: product item, serial number, location, quantities and cost. query: shipment_id. Receipts are created and edited from the ERPmine UI — the REST API is read-only.'],

    # --- Inventory — deliveries (wkdelivery) ----------------------------
    ['list_deliveries', :get, '/wkdelivery.json',
     'List outbound deliveries with their serial number, customer, date, delivery status and value. query: period_type, period, from, to, polymorphic_filter, contact_id, account_id, project_id, delivery_status (L loaded, IT in transit, D delivered), offset, limit.'],
    ['get_delivery', :get, '/wkdelivery/edit.json',
     'Get one delivery with each delivered line and its current status. query: delivery_id. Deliveries are created and dispatched from the ERPmine UI — the REST API is read-only.'],

    # --- Inventory — assets (wkasset) -----------------------------------
    ['list_assets', :get, '/wkasset.json',
     'List fixed assets with their name, serial number, owner type, rate, current value and disposal state. query: name, product_id, brand_id, location_id, project_id, is_dispose ("1" to list disposed assets instead of live ones), offset, limit. Same row shape as list_inventory_items, narrowed to product_type "A".'],
    ['get_asset', :get, '/wkasset/edit.json',
     'Get one asset with its purchase details, asset properties and last depreciation date. query: inventory_item_id.'],
    ['create_asset', :post, '/wkasset/update.json',
     'Register an asset. body is the same shape as create_inventory_item with "product_type": "A", plus the asset properties {"asset_name", "owner_type", "rate", "rate_per", "asset_currency", "latitude", "longitude"}. available_quantity is required; without it no asset is created and the call still returns 200. The response carries no id, so confirm with get_asset.'],
    ['update_asset', :post, '/wkasset/update.json',
     'Update an asset. body {"inventory_item_id", "product_id", "brand_id", "product_model_id", ...other fields from create_asset}. Send product_id, brand_id and product_model_id exactly as get_asset returns them, or a duplicate product item is created. Without available_quantity only selling_price and is_loggable are applied. Confirm the result with get_asset.'],

    # --- Inventory — depreciation (wkassetdepreciation) -----------------
    ['list_asset_depreciations', :get, '/wkassetdepreciation.json',
     'List asset depreciation entries with the purchase value, previous value, depreciation charged and resulting current value. query: period_type, period, from, to, product_id, inventory_item_id, offset, limit. Read-only: running depreciation posts accounting entries and is done from the ERPmine UI.'],

    # --- Survey (wksurvey) ----------------------------------------------
    ['list_surveys', :get, '/wksurvey.json',
     'List surveys with their name and status. query: project_id, offset, limit.'],
    ['get_survey', :get, '/wksurvey/:id/survey.json',
     'Get one survey\'s question groups, questions and answer choices. The :id path parameter is the numeric survey id from list_surveys and query survey_id must repeat it; response_id loads an existing response. Serves only status O or C, so read a draft by setting it to O with a status-only update_survey, then back to N. Each groups entry carries the group id update_survey needs; id 0 means those questions have no group.'],
    ['list_survey_responses', :get, '/wksurvey/:id/survey_response.json',
     'List the responses submitted to one survey, with who responded and when. query: survey_id (the same value as the :id path parameter, required), groupName, offset, limit.'],
    ['get_survey_result', :get, '/wksurvey/:id/survey_result.json',
     'Get one survey\'s aggregated results — answer counts per question and the free-text answers. query: survey_id (the same value as the :id path parameter, required), surveyForType, groupName.'],
    ['create_survey', :post, '/wksurvey/save_survey.json',
     'Create a survey definition. body {"wksurvey": {"name", "status", "survey_for_type", "survey_for_id", "group_id", "recur", "recur_every", "is_review", "use_points", "wk_survey_que_groups_attributes"}}. status is N, O, C or A. survey_for_type is Project, WkAccount, WkCrmContact or User only. survey_for_id targets one record of that type; leave it blank to target every one. Omit both to target nothing. For a user group send group_id (its id from list_groups) and no survey_for_type. Questions go inside groups, never at survey level; name the group as the caller asked, or "" for the ungrouped section. A group takes name, sort_order and wk_survey_questions_attributes; a question takes name, question_type, is_mandatory, sort_order and wk_survey_choices_attributes; a choice takes name and points. Every *_attributes collection is an object keyed "0", "1", "2" — arrays fail. Group sort_order is numeric; question sort_order is an unpadded integer string that sorts as text past nine, and goes last when omitted. Omit "wksurvey": {"id"} to create.'],
    ['update_survey', :post, '/wksurvey/save_survey.json',
     'Update a survey definition. Same body as create_survey plus "wksurvey": {"id"}; each existing group, question and choice carries its own "id", and "_destroy": "1" removes one. Edit only while status is N — on O, C or A send nothing but the status field. To add a question to an existing section send that group with its "id"; a group without an "id" becomes a new section, and "id": 0 is not a group. Same shape and sort_order rules as create_survey.'],
    ['submit_survey_response', :post, '/wksurvey/update_survey.json',
     'Submit or update a respondent\'s answers to a survey. body {"wksurvey": {"survey_id", "id" (the response id — omit it to start a new response), "answers": [{"survey_question_id", "answer_text", "survey_choice_id"}], "reviews": [{"survey_question_id", "comment_text"}]}}. Send "isReview": true when a reviewer is commenting on someone else\'s completed response.'],

    # --- Reports (wkreport) ---------------------------------------------
    # get_reports answers the same full list the web UI shows. Some report_type
    # codes carry a "_web" suffix from their view name; get_report_data and
    # export_report both strip it, so a code can be passed back verbatim.
    ['list_reports', :get, '/wkreport/get_reports.json',
     'List every ERPmine report the caller may see, together with the project, group and location options each report can be filtered by.'],
    ['get_report_data', :get, '/wkreport/get_report_data.json',
     'Run one ERPmine report and get its rows. query: report_type (the report_* code from a list_reports pair, never its label), user_id, group_id, project_id, location_id, from, to.'],
    ['export_report', :get, '/wkreport/export.csv',
     'Run one ERPmine report and get it as CSV, including the presentation rows (headings, sections, totals) that get_report_data leaves out. query: searchlist=wkreport (required), report_type (the report_* code from a list_reports pair, never its label), user_id, group_id, project_id, location_id, period_type, period, from, to. Returns raw CSV text, not JSON.'],

    # --- Settings — enumerations (wkcrmenumeration) ---------------------
    ['list_crm_enumerations', :get, '/wkcrmenumeration/get_crm_enumerations.json',
     'List the ACTIVE values of ONE enumeration as id/name pairs. query: enum_type (required — the endpoint 403s without it): LS lead source, SS sales stage, OT opportunity type, AC account category, PT payment type, LT location type, DP department, CR relationship, SK skill set, IT interview type, EC emergency contact type, MS marital status, DS dept section. This is the lookup to call before a write, to resolve lead_source_id, payment_type_id, relationship_id, account_category, skill_set_id and interview_type. Use list_enumerations instead to see every type at once, or the inactive values.'],
    ['list_enumerations', :get, '/wkcrmenumeration.json',
     'List enumeration values across every type, with their position, active flag and which one is the type default. query: enumType (a code from list_crm_enumerations, omit for all types), enumname (substring match on the name), offset, limit. Unlike list_crm_enumerations this includes inactive values and needs no enum_type. Requires the ERPmine settings permission.'],
    ['get_enumeration', :get, '/wkcrmenumeration/edit.json',
     'Get one enumeration value with its type, position, active flag and default flag. query: enum_id.'],
    ['create_enumeration', :post, '/wkcrmenumeration/update.json',
     'Add a value to an enumeration. body {"enumname", "enumType" (a code from above), "enumPosition", "enumActive": true, "enumDefaultValue": false}. Omit "enum_id" to create. Setting enumDefaultValue true clears the default off every other value of that type.'],
    ['update_enumeration', :post, '/wkcrmenumeration/update.json',
     'Update an enumeration value. body {"enum_id", ...same fields as create_enumeration}. Every field is overwritten from the body, so send them all — a blank "enumname" fails validation. Deactivating (enumActive false) is the safe way to retire a value that existing records still point at.'],

    # --- Settings — locations (wklocation) ------------------------------
    ['list_locations', :get, '/wklocation/getlocations.json',
     'List the ERPmine locations (offices/branches) the caller may use, as id/name pairs. Resolves location_id for the CRM and referral write tools.'],

    # --- Settings — notifications (wknotification) ----------------------
    ['list_notifications', :get, '/wknotification.json',
     'List ERPmine notifications for the calling user, newest first, with their seen/unseen state.'],
    ['mark_notification_read', :get, '/wknotification/update_user_notification.json',
     'Mark one of the calling user\'s notifications as read. query: id (the notification id from list_notifications).'],
    ['mark_all_notifications_read', :post, '/wknotification/mark_read_notification.json',
     'Mark every unread notification of the calling user as read. Takes no body.'],

    # --- Material and asset logs (wklogmaterial) ------------------------
    ['list_material_logs', :get, '/wklogmaterial/index.json',
     'List materials, products and assets logged against issues or projects. query: spent_type (M material, A asset, T time, E expense), project_id, issue_id, user_id, from, to, offset, limit.'],
    ['create_material_log', :post, '/wklogmaterial/create.json',
     'Log a material or asset against an issue. body {"log_type": "M", "wk_material_entry": {"issue_id", "spent_on", "activity_id", "comments", "user_id"}, "inventory_item_id", "product_quantity", "uom_id", "product_sell_price"}. log_type: M material, A asset. The quantity is deducted from the inventory item, so it cannot exceed the available quantity.'],
    ['update_material_log', :post, '/wklogmaterial/update.json',
     'Update a logged material or asset. query: id (the log entry id from list_material_logs). body {"log_type": "M", "matterial_entry_id": <same id>, "wk_material_entry": {"issue_id", "spent_on", "activity_id", "comments"}, "inventory_item_id", "product_quantity", "uom_id", "product_sell_price"}.'],

    # --- Employee self-service (wkbase) ---------------------------------
    ['get_my_erp_profile', :get, '/wkbase/my_account.json',
     'Get the calling user\'s ERPmine employee profile: role, shift, location, department, joining and birth dates, billing rate and currency, employee id, bank and tax details.'],
    ['get_my_erp_permissions', :get, '/wkbase/get_user_permissions.json',
     'Get the calling user\'s ERPmine permission codes plus the plugin settings that control which modules are enabled. Use this to check what the user may do before offering a write tool.'],
    ['clock_in_out', :post, '/wkbase/update_clockinout.json',
     'Clock the calling user in, or out if already clocked in — the endpoint toggles on their last open attendance entry. body {"offSet"} plus optional {"start_time"} or {"end_time"} to stamp another time. offSet follows JavaScript getTimezoneOffset(): minutes to add to local time to reach UTC, negative east of UTC (-330 IST, +300 US Eastern, 0 UTC). Derive it from the caller\'s timezone rather than asking. Check the current state first with get_clock_status.'],
    ['start_issue_timer', :post, '/wkbase/save_issue_log.json',
     'Start a running timer against an issue — creates a time entry that accrues until it is stopped. body {"issue_id", "offSet"} plus optional {"longitude", "latitude", "device_id"}. offSet is required and follows the same rule as clock_in_out. Call it directly — no approval preview.'],
    ['stop_issue_timer', :post, '/wkbase/save_issue_log.json',
     'Stop a running issue timer and write the elapsed hours onto its time entry. body {"id": <the timer id from list_running_timers>, "offSet"} plus optional {"longitude", "latitude", "device_id"}. offSet is required and follows the same rule as clock_in_out. Call it directly — no approval preview.'],

    # --- Lookups --------------------------------------------------------
    ['list_crm_related_records', :get, '/wkcrm/get_act_related_ids.json',
     'List the records a CRM activity or contact can be attached to, as id/name pairs. query: related_type (WkAccount, WkCrmContact, WkLead or WkOpportunity), account_type, contact_type. Resolves related_parent for create_crm_activity and create_crm_contact.'],
    ['list_loggable_projects', :get, '/wktime/get_projects',
     'List the projects the caller may log time or expense against, as id/name pairs. query: user_id (required). Resolves project_id for the timesheet and expense write tools. Note this path has no .json suffix — the endpoint always answers JSON.'],
    ['search_loggable_issues', :get, '/wktime/getissues.json',
     'Search the issues the caller may log time against, as id/label pairs. query: user_id (required), term (subject or issue number to match), project_id, tracker_id, startday. Resolves issue_id for the timesheet, expense and material write tools.'],
    ['list_loggable_activities', :get, '/wktime/getactivities',
     'List the time-entry activities valid for a project, as id/name pairs. query: project_id, or issue_id together with user_id. Resolves activity_id for the timesheet and expense write tools. Note this path has no .json suffix — the endpoint always answers JSON.'],
    ['list_loggable_clients', :get, '/wktime/getclients.json',
     'List the clients (account/contact a project is billed to) that time can be logged against, as value/label pairs. query: user_id plus project_id or issue_id. Resolves spent_for_id for the timesheet write tools.'],
    ['list_running_timers', :get, '/wktime/get_issue_loggers.json',
     'List the caller\'s currently running issue timers with the issue and the time they started. query: type=finish (required). Gives the id that stop_issue_timer needs.'],
    ['list_expensable_projects', :get, '/wkexpense/get_projects',
     'List the projects the caller may log expense against, as id/name pairs. query: user_id (required). Resolves project_id for the expense write tools — the expense module has its own project permissions, so this can differ from list_loggable_projects. Note this path has no .json suffix — the endpoint always answers JSON.'],
    ['list_expense_currencies', :get, '/wkexpense/get_currency.json',
     'List the currencies an expense entry may be recorded in, as code/name pairs.'],
    ['list_leave_types', :get, '/wkleaverequest/get_leave_options.json',
     'List the leave types the caller may request, as id/name pairs. Resolves leave_type_id for create_leave_request.'],
    ['get_clock_status', :get, '/wkattendance/get_clock_hours.json',
     'Get the calling user\'s current clock state — whether they are clocked in, when the open entry started, and the hours worked so far today. Check this before calling clock_in_out.'],
    ['list_invoice_projects', :get, '/wkinvoice/get_inv_proj.json',
     'List the projects that can be billed on an invoice, as id/name pairs. query: parent_type, parent_id (the account or contact being invoiced), new_invoice=true when composing a new invoice, invoice_id when editing one. Resolves project_id_1 for create_invoice.'],
    ['list_account_projects', :get, '/wkinvoice/get_account_proj_ids.json',
     'List the projects linked to one CRM account or contact, as id/name pairs. query: parent_type ("WkAccount" or "WkCrmContact"), parent_id.'],
    ['list_material_log_types', :get, '/wklogmaterial/load_spent_type.json',
     'List the log types the caller may record against an issue, as code/name pairs (T time, E expense, M material, A asset). Gives the log_type / spent_type values the material tools take.'],
    ['list_products', :get, '/wklogmaterial/modify_product_dd.json',
     'List inventory dropdowns, as value/label pairs. query: ptype, id, log_type. Chain: ptype=product with log_type=M gives a product id; ptype=product_item with that id and log_type=I gives inventory_item_id; ptype=inventory_item and ptype=uom_id with inventory_item_id give available_quantity, selling_price and uom_id. For assets pass log_type=A throughout.'],
    ['search_survey_targets', :get, '/wksurvey/find_survey_for.json',
     'Search the records a survey can be attached to, as id/label pairs. query: surveyFor ("Project", "WkAccount", "WkCrmContact", "User", …), surveyForID (an id, or a search term with method=search), method. Resolves survey_for_type and survey_for_id for create_survey. Only needed when targeting one record; a blank survey_for_id covers all of a type.']
  ].freeze

  # Hook entry point. redmine_mcp's catalogue merges the returned rows.
  def redmine_mcp_register_tools(context = {})
    ENDPOINTS
  end

  # Which plugin these tools belong to. redmine_mcp's settings page lists the
  # rows above under this plugin's name, in their own table, instead of mixing
  # them into the core Redmine tool list (see RedmineMcp::Catalog#group_label).
  def mcp_plugin_id
    :redmine_wktime
  end
end
