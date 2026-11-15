from pathlib import Path
from copy import deepcopy
import re,shutil,hashlib,textwrap
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.enum.section import WD_SECTION_START
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
R=Path(__file__).parent; O=R/'05_Project_Report/College_Submission';O.mkdir(exist_ok=True)
ref=R/'05_Project_Report/College_Format_Reference.docx'
d=Document(ref); md=[]
cover=[deepcopy(x._p) for x in d.paragraphs[:38]]
for el in list(d.element.body):
 if el.tag!=qn('w:sectPr'):d.element.body.remove(el)
for el in cover:d.element.body.insert(len(d.element.body)-1,el)
replacements={0:'EV Charging Station Management System',4:'Database Management System – [Course code]',16:'25R11A67E4    Rohit Kumar Garre',17:'25R11A67G7    Nagula Prasun Reddy',18:'25R11A67E1    Divi Laxmi Venkata Manidhar',24:'[Faculty guide name]'}
for i,v in replacements.items():d.paragraphs[i].text=v
for i,p in enumerate(d.paragraphs):
 p.alignment=1;p.paragraph_format.space_before=Pt(0);p.paragraph_format.space_after=Pt(0);p.paragraph_format.line_spacing=1
 for r in p.runs:r.font.name='Times New Roman';r.font.size=Pt(12);r.font.color.rgb=RGBColor(0,0,0)
 if not p.text.strip():p.paragraph_format.line_spacing=Pt(5);p.paragraph_format.space_after=Pt(0)
 if i in [0,7,11,32]:
  for r in p.runs:r.bold=True;r.font.size=Pt(16 if i in [0,32] else 12)
from io import BytesIO
logo=d.part.rels['rId7'].target_part.blob
lp=d.paragraphs[28];lp.clear();lp.paragraph_format.line_spacing=1;lp.add_run().add_picture(BytesIO(logo),width=Inches(1.15))
for name in ['Normal','Heading 1','Heading 2','Heading 3','Caption']:
 if name not in d.styles:d.styles.add_style(name,1)
 st=d.styles[name];st.font.name='Times New Roman';st.font.color.rgb=RGBColor(0,0,0)
 st.font.size=Pt({'Heading 1':16,'Heading 2':14}.get(name,12))
 st.paragraph_format.line_spacing=1.5
 if name.startswith('Heading'):st.font.bold=True;st.paragraph_format.space_after=Pt(18);st.paragraph_format.space_before=Pt(12)
d.styles['Normal'].paragraph_format.first_line_indent=Inches(.35)
d.styles['Normal'].paragraph_format.alignment=3
d.styles['Normal'].paragraph_format.space_after=Pt(6)
st=d.styles.add_style('SQL listing',1);st.font.name='Consolas';st.font.size=Pt(9);st.paragraph_format.line_spacing=1;st.paragraph_format.space_after=Pt(0)
def geometry(s):
 s.page_width=Inches(8.27);s.page_height=Inches(11.69);s.left_margin=Inches(1.5);s.right_margin=Inches(1);s.top_margin=s.bottom_margin=Inches(1)
geometry(d.sections[0])
def section(fmt,start):
 s=d.add_section(WD_SECTION_START.NEW_PAGE);geometry(s);s.footer.is_linked_to_previous=False
 p=s.footer.paragraphs[0];p.alignment=1;p.paragraph_format.first_line_indent=Pt(0)
 ff=OxmlElement('w:fldSimple');ff.set(qn('w:instr'),'PAGE');p._p.append(ff)
 num=OxmlElement('w:pgNumType');num.set(qn('w:fmt'),fmt);num.set(qn('w:start'),str(start));s._sectPr.append(num)
 return s
def p(t):d.add_paragraph(t);md.append(t+'\n')
def h(t,l=1):d.add_heading(t,l);md.append('#'*l+' '+t+'\n')
def code(t):
 md.append('```sql\n'+t+'\n```\n')
 for line in t.splitlines():
  for ln in textwrap.wrap(line,77,replace_whitespace=False,drop_whitespace=False) or ['']:d.add_paragraph(ln,'SQL listing')
 d.add_paragraph().paragraph_format.space_after=Pt(0)
def table(headers,rows):
 t=d.add_table(rows=1,cols=len(headers));t.style='Table Grid'
 for c,v in zip(t.rows[0].cells,headers):c.text=v
 for row in rows:
  for c,v in zip(t.add_row().cells,row):c.text=str(v)
 for i,row in enumerate(t.rows):
  pr=row._tr.get_or_add_trPr();pr.append(OxmlElement('w:cantSplit'))
  if i==0:pr.append(OxmlElement('w:tblHeader'))
  for c in row.cells:
   if i==0:
    sh=OxmlElement('w:shd');sh.set(qn('w:fill'),'DFE8F0');c._tc.get_or_add_tcPr().append(sh)
   for pp in c.paragraphs:
    pp.alignment=0;pp.paragraph_format.first_line_indent=Pt(0);pp.paragraph_format.line_spacing=1.05;pp.paragraph_format.space_after=Pt(5);pp.paragraph_format.space_before=Pt(5)
    for r in pp.runs:r.font.name='Times New Roman';r.font.size=Pt(11);r.bold=i==0
 md.append('| '+' | '.join(headers)+' |\n|'+'---|'*len(headers)+'\n'+'\n'.join('| '+' | '.join(map(str,row))+' |' for row in rows)+'\n')
section('lowerRoman',1);h('Table of Contents')
f=OxmlElement('w:fldSimple');f.set(qn('w:instr'),'TOC \\o "1-1" \\h \\z \\u');d.add_paragraph()._p.append(f)
d.add_page_break();h('Abstract')
p('The EV Charging Station Management System is a MySQL database project for organizing drivers, station locations, chargers, reservations, charging sessions and payments. Six related tables model the operational lifecycle. Primary and foreign keys preserve identity and references, while unique and check constraints restrict invalid records. Stored procedures coordinate booking, session initiation, charging completion, bill calculation and payment status updates. Triggers support time validation, tariff capture and status synchronization. Views and SQL queries expose reservation history, energy consumption and revenue.')
p('The project demonstrates relational design, normalization, joins, aggregation and transaction processing through MySQL Workbench. It is a database implementation rather than a deployed web application. This report presents the architecture, supplied ER diagram, representative implementation code and a reproducible usage sequence. Static calculations from the sample data are distinguished from historical test summaries. Implementation limitations include incomplete lifecycle validation, direct SQL bypass of procedural rules and a summary count that requires correction.')
p('Keywords — MySQL, EV charging, relational database, normalization, stored procedures.')
section('decimal',1);h('1 Introduction')
h('1.1 About the Project',2)
p('A charging station contains several charging units with different power ratings and prices. A driver books a unit for a time interval, charging records the actual energy delivered, and payment records describe the resulting invoice. These facts must remain connected without repeatedly storing user contact details or station addresses in every transaction.')
p('The proposed database maintains a traceable chain from a reservation to its session and payment. It separates station infrastructure from transactional activity so that a station or charger can exist before its first booking. The project uses SQL scripts, MySQL InnoDB and MySQL Workbench.')
h('1.2 Problem Statement and Objectives',2)
p('The problem is to organize charging reservations and billing records while preserving referential integrity and supporting useful reports. The objectives are to manage users and chargers, validate reservation intervals, capture session prices, calculate bills, record payment states and demonstrate retrieval through simple and advanced SQL.')
h('1.3 Scope and Expected Outcomes',2)
p('The implementation contains six core tables, four triggers, six stored procedures, five views and 32 demonstration queries. Students can use it to explain schema design, primary and foreign keys, 3NF, transactions, joins and aggregate functions. Hardware integration, online banking, map services and a mobile interface are outside the implemented scope.')
d.add_page_break();h('2 Data Base System Design')
h('2.1 System Architecture and Modules',2)
table(['Module','Responsibility'],[['User and infrastructure','users, stations and chargers store identities, locations and tariffs'],['Reservation','bookings stores intervals and reservation state'],['Charging','charging_sessions stores actual time, energy and rate snapshot'],['Payment','payments stores invoice amount and settlement state'],['Reporting','Views and queries combine operational and financial records']])
p('The operator issues SQL in Workbench or the mysql client. Stored procedures coordinate multi statement changes, InnoDB stores the related records, and views return tabular results. The workflow is select charger, reserve slot, start session, complete charging, record payment and review reports.')
h('2.2 Relationships and Integrity',2)
table(['Parent and child','Cardinality'],[['users to bookings','1 to 0..N'],['stations to chargers','1 to 0..N'],['chargers to bookings','1 to 0..N'],['bookings to charging_sessions','1 to 0..1'],['charging_sessions to payments','1 to 0..1']])
p('Each child has a nonnullable foreign key. All foreign keys use ON DELETE RESTRICT and ON UPDATE CASCADE. Unique booking_id in sessions and unique session_id in payments enforce the optional one to one links. The charger code is unique within a station.')
d.add_page_break();h('2.3 Entity Relationship Diagram',2)
img=R/'05_Project_Report/Compact_Submission/ER_Diagram_Supplied.png';shutil.copy2(img,O/img.name)
d.add_picture(str(img),width=Inches(5.4));md.append('![ER diagram](ER_Diagram_Supplied.png)\n')
p('Figure 1 Entity Relationship Diagram in Chen Notation')
p('The supplied diagram contains all 37 columns of the six core entities. Rectangles represent entities, ovals represent attributes and diamonds represent relationships. Primary keys are underlined. The diagram also identifies foreign keys, unique keys and relationship cardinalities.')
h('2.4 Normalization',2)
p('The schema uses atomic column values for 1NF. Nonkey attributes depend on the complete candidate key, satisfying 2NF under the modeled dependencies. Separating user, station and charger facts avoids nonkey transitive dependencies in transaction tables, supporting 3NF. A surrogate identifier alone is not proof of normalization; alternate candidate keys include users.email and the station_id plus charger_code pair.')
p('The session tariff records a historical price, distinct from the current charger rate. Direct SQL can still edit this snapshot; the ledger is not immutable.')
d.add_page_break();h('3 Implementation')
h('3.1 Interface and Setup',2)
p('Open an authorized MySQL Workbench connection. Use File > Open SQL Script and run scripts 01 through 06 in 02_SQL_Scripts in numerical order. Refresh the Schemas panel to inspect ev_charging_management. Run 03_Sample_Data/01_seed_data.sql only for a disposable demonstration dataset because it truncates the core tables. The index script cannot be rerun unchanged after its index names exist.')
code('CREATE DATABASE IF NOT EXISTS ev_charging_management;\nUSE ev_charging_management;\nSELECT DATABASE(), VERSION();\nSHOW TABLES;\nSHOW TRIGGERS;')
p('In the mysql command line, start the client from the project root and use SOURCE 02_SQL_Scripts/08_full_project_setup.sql for a fresh setup. In Workbench, execute the component files individually. The master script also runs the destructive seed operation.')
h('3.2 Table Creation',2)
p('The complete six table definitions below are taken from the implemented schema. They show types, keys, defaults and checks directly, following the sample case study’s code focused approach.')
schema=(R/'02_SQL_Scripts/02_create_tables.sql').read_text(encoding='utf-8-sig')
for stmt in re.findall(r'CREATE TABLE IF NOT EXISTS.*?;',schema,re.S):
 name=re.search(r'EXISTS (\w+)',stmt)[1];h(name,3)
 code(re.sub(r'\n\s*','\n  ',stmt).replace('DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci','DEFAULT CHARSET=utf8mb4\nCOLLATE=utf8mb4_unicode_ci'))
h('3.3 Insertion of Sample Values',2)
p('The original seed contains 20 users, 8 stations, 24 chargers, 60 bookings, 30 sessions and 25 payments. The following connected rows are extracted from that seed. They illustrate the data; do not insert them again into an already seeded database because their keys already exist.')
seed=(R/'03_Sample_Data/01_seed_data.sql').read_text(encoding='utf-8-sig')
clean=re.sub(r'--[^\n]*','',seed)
for name,cols,values in re.findall(r'INSERT INTO (\w+) \((.*?)\) VALUES\s*(.*?);',clean,re.S):
 row=re.search(r'\([^\n]+?\)',values)[0]
 # Session 1 references booking 1 and charger 2; use charger 2.
 if name=='chargers':row=re.findall(r'\([^\n]+?\)',values)[1]
 code('INSERT INTO '+name+' ('+cols+')\nVALUES '+row+';')
h('3.4 Simple SQL Queries and Joins',2)
code("SELECT * FROM stations ORDER BY state, city;\nSELECT charger_code, power_kw, rate_per_kwh\nFROM chargers\nWHERE status='ACTIVE' AND charger_type='DC'\nORDER BY power_kw DESC;")
p('Selection and ordering list stations and operational fast chargers. Operational status alone does not establish that a requested reservation interval is free.')
code('SELECT b.booking_id, u.full_name, c.charger_code,\n       s.station_name, b.start_time, b.status\nFROM bookings b\nJOIN users u ON b.user_id=u.user_id\nJOIN chargers c ON b.charger_id=c.charger_id\nJOIN stations s ON c.station_id=s.station_id;')
p('The join retrieves customer, charger and station context through foreign keys without copying those fields into the booking table.')
h('3.5 Aggregate Functions and Subquery',2)
code("SELECT c.charger_type, COUNT(*) AS session_count,\n SUM(cs.energy_kwh) AS total_kwh, AVG(cs.energy_kwh) AS avg_kwh,\n MIN(cs.energy_kwh) AS min_kwh, MAX(cs.energy_kwh) AS max_kwh\nFROM charging_sessions cs\nJOIN bookings b ON cs.booking_id=b.booking_id\nJOIN chargers c ON b.charger_id=c.charger_id\nWHERE cs.status='COMPLETED'\nGROUP BY c.charger_type\nHAVING SUM(cs.energy_kwh)>50;\n\nSELECT charger_code, rate_per_kwh FROM chargers\nWHERE rate_per_kwh > (SELECT AVG(rate_per_kwh) FROM chargers);")
p('WHERE filters rows before grouping, while HAVING filters groups. The scalar subquery supplies the mean catalog price. The complete query collection additionally demonstrates CTEs, DENSE_RANK, LAG and EXPLAIN.')
h('3.6 Trigger Implementation',2)
p('The session completion trigger updates its booking when the session changes to COMPLETED. The booking insert trigger rejects reversed intervals. These are actual source definitions; no trigger prevents overlapping bookings.')
tr=(R/'02_SQL_Scripts/04_triggers.sql').read_text(encoding='utf-8-sig')
for name in ['trg_bookings_before_insert','trg_sessions_after_update']:
 stmt=re.search(r'CREATE TRIGGER '+name+r'.*?END\$\$',tr,re.S)[0]
 code('DELIMITER $$\n'+stmt+'\nDELIMITER ;')
p('The remaining triggers supply session tariffs when required and payment completion timestamps. They do not make rates immutable or automatically generate invoices for direct INSERT operations.')
h('3.7 Stored Procedure and Reporting',2)
p('sp_calculate_bill joins session, reservation, driver, charger and station information. Its OUT parameters return a bill breakdown. This definition is included as a complete stored procedure example.')
proc=(R/'02_SQL_Scripts/05_stored_procedures.sql').read_text(encoding='utf-8-sig')
stmt=re.search(r'CREATE PROCEDURE sp_calculate_bill\(.*?END\$\$',proc,re.S)[0]
code('DELIMITER $$\n'+stmt+'\nDELIMITER ;')
code('CALL sp_calculate_bill(1, @user, @station, @charger,\n @kwh, @rate, @total);\nSELECT @user, @station, @charger, @kwh, @rate, @total;\nCALL sp_station_revenue_report(NULL);')
h('3.8 End to End Demonstration',2)
p('Use a disposable database and run one call at a time. Confirm the user and charger exist, select a free interval, and continue only when the preceding status is SUCCESS. These calls illustrate operation; they were not executed during report preparation.')
code("CALL sp_book_charger_slot(1,2,\n '2026-11-21 10:00:00','2026-11-21 11:00:00',\n @booking,@status,@message);\nSELECT @booking,@status,@message;\nCALL sp_start_charging_session(@booking,\n @session,@status,@message);\nSELECT @session,@status,@message;\nCALL sp_complete_charging_session(@session,10.000,\n @amount,@status,@message);\nSELECT @amount,@status,@message;\nCALL sp_process_payment(@session,'UPI','COMPLETED',\n @status,@message);\nSELECT @status,@message;\nSELECT * FROM vw_payment_audit_log\nWHERE session_id=@session;")
p('Booking validates the user and charger and checks overlap. Start captures a tariff. Completion records energy and creates a pending invoice. Payment processing records a simulated settlement state without contacting a bank. Procedures manage transactions and roll back on SQL errors.')
h('3.9 Results and Testing',2)
table(['Metric','Value from seed source'],[['Core table row counts','20 users; 8 stations; 24 chargers; 60 bookings; 30 sessions; 25 payments'],['Completed payments','20'],['Completed payment total','INR 19,779.73'],['Session 1 bill','42.500 kWh × INR 19.50 = INR 828.75']])
p('These figures are static calculations from INSERT values, not newly captured MySQL outputs. The saved test summary claims 20 passing tests, but the tests were not rerun. The saved monthly revenue of INR 18,942.28 conflicts with the seed total. No query screenshots are invented.')
p('Limitations include inconsistent states for bookings 28–30, overcounting of operational chargers after joins, and weak assertions in tests 19 and 20. Concurrent booking safety needs separate connection tests. Run the test harness only on a disposable copy.')
p('Complete_SQL_Companion.md includes all 32 queries and every SQL script. Original executable files remain unchanged.')
d.add_page_break();h('4 Conclusion')
p('The EV Charging Station Management System demonstrates how relational modeling supports a charging workflow from reservation to payment. Separate infrastructure and transaction tables reduce repeated data, foreign keys preserve references, and stored procedures provide reusable business operations. The captured tariff supports historical billing, while SQL joins and aggregate queries make the records useful for reporting.')
p('The project provides an academic implementation of MySQL tables, constraints, normalization, triggers and procedures. It does not establish production readiness or independently verified live test success. Improvements should first correct summary counting, reconcile sample states and strengthen procedural and concurrency tests. A web interface, authenticated roles, live charger monitoring, payment integration and notifications are future extensions.')
h('5 References')
p('Oracle. MySQL 8.4 Reference Manual. CREATE TABLE Statement. Consulted 15 November 2026. https://dev.mysql.com/doc/refman/8.4/en/create-table.html')
p('Oracle. MySQL 8.4 Reference Manual. Locking Reads. Consulted 15 November 2026. https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html')
p('EV Charging Station Management project sources. 02_SQL_Scripts, 03_Sample_Data and 07_Testing. Historical evidence in Test_Results.md and Test_Summary.md.')
for s in d.sections:geometry(s)
d.save(O/'EV_Charging_PBL_College_Format.docx')
(O/'Report_Source.md').write_text('\n'.join(md),encoding='utf-8')
shutil.copy2(R/'05_Project_Report/Compact_Submission/Complete_SQL_Companion.md',O/'Complete_SQL_Companion.md')
(O/'artifact.md').write_text('Reference: '+str(ref)+'\nSHA256: '+hashlib.sha256(ref.read_bytes()).hexdigest()+'\nCollege title wording and source cover elements retained. Body follows required Abstract, Introduction, Data Base System Design, Implementation, Conclusion and References order. A4; margins left 1.5, right/top/bottom 1 inch. Times New Roman 12 body, 16 chapter, 14 headings; justified body, first line tab-equivalent indent, 1.5 spacing. Cover no number; contents and abstract lower Roman; body Arabic restarted at 1, bottom center. Source instructional pages removed. Original sample is a content reference only. SQL uses compact monospace listings as an intentional readability exception. Faculty name and course code unresolved. Supplied ER image retained unchanged.\n',encoding='utf-8')
print(O)
