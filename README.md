# Webinar on ERPmine – CRM, Feb 24th, 2026,(11:30 AM GMT)

Please click here to register if interested,
[[https://us02web.zoom.us/meeting/register/aM-1Nt__TBafjqbeJQjdVw]](https://us02web.zoom.us/meeting/register/8M1jhRftTmezDJZUNvuEcw)

**Topics**:
 -  Leads
 -   Accounts
 -   Contacts 
 -   Opportunities
 -   Activities
 -   Sales Quote
 -   Reports
 -   Mobile app

-----

# ERPmine

This Plugin has the following modules:

**Time and Expense**
- Submit Time & Expense Sheets
- Approve Time & Expense Sheets
- Print Time & Expense Sheets

**Attendance**
- Clock In / Clock Out
- Check Leave Status
- Leave Request
- Integrate with Attendance / Time clock devices
- Schedule Shifts
- Skills
- Referrals
- User Unbilledtilization Report

**PayRoll**
- Setup Payroll data
- Generate/Preview Salary
- Payroll Report
- Pay Slip Report
- Payroll Bank Report

**Billing**
- Setup Billable Projects
- Generate/Unbilled Invoices
- Payments
- Print Invoices
- Project profitability Report

**Accounting**
- Create Ledgers
- Post Financial Transaction
- Balance Sheet Report
- Profit & Loss A/c Report
- Trail Balance Report

**CRM**
- Create Leads, Accounts, Contacts, Opportunity and Activity
- Lead Conversion Report
- Sales Activity Report

**Purchasing**
- Create RFQ, Quote, Purchase Order,
- Create Supplier Invoice and Supplier Payments
- Purchasing cycle Report

**Inventory**
- Create Product, Items, Receipts, Assets and Depreciation
- Log Material and Asset Entries
- Stock and Asset Report

**Survey**
- Create Project, Account, Contact, User and General survey
- Recursive survey
- Survey Responses
- Survey Result

**Dashboards**
- Clock in users
- Expense for issues
- Lead generation vs conversion
- Invoice vs Payment
- Assets
- Profit and loss

For more information on features, please refer to the user guide

(https://erpmine.org/attachments/download/223/ERPmine-User-Guide_v4.7.pdf)
## Installation

- Unpack the zip file to the plugins folder of Redmine.

- Run the following command to install the rufus-scheduler gem
  ```sh
  bundle install
  ```

- Run the following command for db migration
  ```sh
  rake redmine:plugins:migrate NAME=redmine_wktime RAILS_ENV=production
  ```

- Run the following command to load default data
  ```sh
  bundle exec rake erpmine:load_default_data RAILS_ENV=production
  ```

- Please make sure public/plugin_asset/redmine_wktime has proper access.

- For rufus-scheduler to work, the rails application should be up all the time.
  If an apache passenger module is used then make sure the following settings are made
    1. PassengerMinInstances 1
    2. RailsAppSpawnerIdleTime 0
    3. PassengerPreStart https://rails-app-url/

## Uninstallation

- When uninstalling the plugin, be sure to remove the db changes by running
  ```sh
  rake redmine:plugins:migrate NAME=redmine_wktime VERSION=0 RAILS_ENV=production
  ```

## Compatibility Matrix

| **Redmine** | **ERPmine** |
|-------------|-------------|
| 6.1.x | 4.9.1, 4.9.2 |
| 6.0.x | 4.8, 4.8.1, 4.8.2, 4.8.3, 4.8.4, 4.8.5, 4.9 |
| 5.1.x | 4.7.1, 4.7.2, 4.7.3, 4.7.4, 4.7.5, 4.7.6 |
| 5.0.x | 4.5.2, 4.6, 4.7 |
| 4.2.0 | 4.2.1, 4.3, 4.3.1, 4.4, 4.4.1, 4.5, 4.5.1 |
| 4.1.1 | 4.0.2, 4.0.3, 4.0.4, 4.1, 4.1.1, 4.2 |
| 4.1.0 | 3.9.1, 3.9.2, 3.9.3, 4.0 |
| 4.0.x | 3.4, 3.5, 3.6, 3.7, 3.8, 3.9 |
| 3.4.x | 2.9, 3.0, 3.1, 3.2, 3.3 |

## Release Notes for v4.9.2

- **Features**
  ```text
   - Added Survey Question Groups
  ```

## Customization

For any Customization/Support, please contact us, our consulting team will be happy to help you

Adhi Software Pvt Ltd
12/B-35, 6th Cross Road
SIPCOT IT Park, Siruseri
Kancheepuram Dist
Tamilnadu - 603103
India

Website: [https://www.adhisoftware.co.in](https://www.adhisoftware.co.in)
Email: info@adhisoftware.co.in
Phone: +91 44 27470401

Here are the Customizations we have done for our clients:
1. Monthly Calendar - Puny Human
2. Supervisor Approvals - Fotonation
3. Hide Modules and Limit Non Submission Mail - Lyra Network

Please provide your rating at [https://www.redmine.org/plugins/wk-time](https://www.redmine.org/plugins/wk-time)

## Resources

**User guide**:

- [http://erpmine.org/attachments/download/115/ERPmine-User-Guide_v4.5.pdf](http://erpmine.org/attachments/download/115/ERPmine-User-Guide_v4.5.pdf)

**Overview presentation in open office format**:

- [https://erpmine.org/documents/1](https://erpmine.org/documents/1)

**Training Videos**:

- [https://www.youtube.com/watch?v=CUsSOdnNq70](https://www.youtube.com/watch?v=CUsSOdnNq70)
- [https://www.youtube.com/watch?v=hTgDepFzGXY](https://www.youtube.com/watch?v=hTgDepFzGXY)
- [https://www.youtube.com/watch?v=5IgBbhrVF4k](https://www.youtube.com/watch?v=5IgBbhrVF4k)
- [https://www.youtube.com/watch?v=ik4jgTMtbvU](https://www.youtube.com/watch?v=ik4jgTMtbvU)
- [https://www.youtube.com/watch?v=weZk70ReZXA]

**For more**:

- [http://erpmine.org/projects/erpmine/wiki/Resources](http://erpmine.org/projects/erpmine/wiki/Resources)
