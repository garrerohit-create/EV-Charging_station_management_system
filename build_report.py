from pathlib import Path
import re, textwrap, json
from decimal import Decimal
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).parent
OUT=ROOT/'05_Project_Report/Final_Submission'
OUT.mkdir(parents=True,exist_ok=True)
AS=OUT/'assets'; AS.mkdir(exist_ok=True)
doc=Document(); sec=doc.sections[0]
sec.page_height=Inches(11.69); sec.page_width=Inches(8.27)
sec.top_margin=sec.bottom_margin=Inches(.75); sec.left_margin=Inches(.9); sec.right_margin=Inches(.75)
for name in ['Normal','Title','Subtitle','Heading 1','Heading 2','Heading 3']:
 s=doc.styles[name]; s.font.name='Times New Roman'; s.font.color.rgb=RGBColor(0,0,0)
doc.styles['Normal'].font.size=Pt(12); doc.styles['Normal'].paragraph_format.line_spacing=1.4
for sty in doc.styles:
 for border in list(sty.element.iter(qn('w:pBdr'))): border.getparent().remove(border)
doc.styles['Normal'].paragraph_format.space_after=Pt(6)
for n,size in [('Title',24),('Heading 1',16),('Heading 2',14),('Heading 3',12)]: doc.styles[n].font.size=Pt(size)
st=doc.styles.add_style('SQL',1); st.font.name='Consolas'; st.font.size=Pt(8)
st.paragraph_format.line_spacing=1; st.paragraph_format.space_after=Pt(0)
sec.header.paragraphs[0].text='EV CHARGING STATION MANAGEMENT  |  DBMS PBL'
sec.header.paragraphs[0].runs[0].font.size=Pt(9)
p=sec.footer.paragraphs[0]; p.alignment=2
p.add_run('Page '); field=OxmlElement('w:fldSimple'); field.set(qn('w:instr'),'PAGE'); p._p.append(field)
md=[]
def h(t,l=1):
 if l==1: doc.add_page_break()
 doc.add_heading(t,l); md.append('\n'+'#'*l+' '+t+'\n')
def p(t):
 doc.add_paragraph(t); md.append(t+'\n')
def code(t):
 md.append('```sql\n'+t+'\n```\n')
 for line in t.splitlines():
  for wrapped in textwrap.wrap(line,94,replace_whitespace=False,drop_whitespace=False) or ['']:
   doc.add_paragraph(wrapped,'SQL')
 doc.add_paragraph().paragraph_format.space_after=Pt(2)
def table(headers,rows):
 t=doc.add_table(rows=1, cols=len(headers)); t.autofit=False
 for i,x in enumerate(headers): t.rows[0].cells[i].text=x
 for row in rows:
  for c,x in zip(t.add_row().cells,row): c.text=str(x)
 for ri,row in enumerate(t.rows):
  pr=row._tr.get_or_add_trPr(); ns=OxmlElement('w:cantSplit'); pr.append(ns)
  if ri==0: pr.append(OxmlElement('w:tblHeader'))
  for c in row.cells:
   cp=c._tc.get_or_add_tcPr(); borders=OxmlElement('w:tcBorders')
   for side in ['top','bottom','left','right']:
    e=OxmlElement('w:'+side); e.set(qn('w:val'),'single'); e.set(qn('w:sz'),'4'); e.set(qn('w:color'),'D9D9D9'); borders.append(e)
   cp.append(borders)
   if ri==0:
    fill=OxmlElement('w:shd'); fill.set(qn('w:fill'),'E4EAF0'); cp.append(fill)
   for pp in c.paragraphs:
    pp.paragraph_format.line_spacing=1.05; pp.paragraph_format.space_before=Pt(4); pp.paragraph_format.space_after=Pt(4)
    for r in pp.runs: r.font.size=Pt(9); r.bold=(ri==0)
 md.append('| '+' | '.join(headers)+' |\n|'+'---|'*len(headers)+'\n'+'\n'.join('| '+' | '.join(map(str,r))+' |' for r in rows)+'\n')
def figure(name,caption):
 doc.add_picture(str(AS/name),width=Inches(6.5)); doc.add_paragraph(caption,'Caption'); md.append(f'![{caption}](assets/{name})\n')
fontpath='C:/Windows/Fonts/arial.ttf'
def diagram(name,boxes,edges,chen=False):
 im=Image.new('RGB',(1800,1250),'white'); d=ImageDraw.Draw(im); f=ImageFont.truetype(fontpath,25)
 for a,b,label in edges:
  x,y=boxes[a][0:2]; xx,yy=boxes[b][0:2]; d.line((x,y,xx,yy),fill='#334155',width=4)
  mx,my=(x+xx)//2,(y+yy)//2
  if chen:
   d.polygon([(mx-105,my),(mx,my-48),(mx+105,my),(mx,my+48)],fill='white',outline='#334155',width=3)
  else: d.rectangle((mx-85,my-20,mx+85,my+20),fill='white')
  d.text((mx,my),label,font=f,fill='black',anchor='mm')
 for key,(x,y,title,lines) in boxes.items():
  if chen:
   d.rectangle((x-150,y-40,x+150,y+40),fill='#e4eaf0',outline='black',width=3); d.text((x,y),title,font=f,fill='black',anchor='mm')
   for i,attr in enumerate(lines):
    ax=x-210+i*210; ay=y-130
    d.line((x,y-40,ax,ay+26),fill='black',width=2); d.ellipse((ax-90,ay-28,ax+90,ay+28),fill='white',outline='black',width=2)
    d.text((ax,ay),attr,font=ImageFont.truetype(fontpath,20),fill='black',anchor='mm')
    if i==0: d.line((ax-65,ay+13,ax+65,ay+13),fill='black',width=2)
  else:
   ht=55+len(lines)*35; d.rectangle((x-245,y-ht//2,x+245,y+ht//2),fill='#f7f9fb',outline='#334155',width=3)
   d.text((x,y-ht//2+25),title,font=f,fill='black',anchor='mm')
   for i,line in enumerate(lines): d.text((x-225,y-ht//2+55+i*35),line,font=ImageFont.truetype(fontpath,23),fill='black')
 im.save(AS/name)
schema=(ROOT/'02_SQL_Scripts/02_create_tables.sql').read_text(encoding='utf-8-sig')
entities={}
for name,body in re.findall(r'CREATE TABLE IF NOT EXISTS (\w+) \((.*?)\) ENGINE',schema,re.S):
 attrs=[]
 for line in body.splitlines():
  m=re.match(r'\s*(\w+) (INT|VARCHAR\(\d+\)|DATETIME|DECIMAL\(\d+,\d+\)|ENUM\([^\n]+?\))(.*)',line)
  if m: attrs.append(m.groups())
 entities[name]=attrs
boxes={}; coords=[(400,260),(1400,260),(1400,620),(400,620),(400,1020),(1400,1020)]
for (name,attrs),(x,y) in zip(entities.items(),coords): boxes[name]=(x,y,name.upper(),[a[0] for a in attrs])
# Deliberate schema positions follow the FK hierarchy.
boxes['chargers']=(1400,620,'CHARGERS',[a[0] for a in entities['chargers']])
boxes['bookings']=(400,620,'BOOKINGS',[a[0] for a in entities['bookings']])
edges=[('users','bookings','1 : 0..N'),('stations','chargers','1 : 0..N'),('chargers','bookings','1 : 0..N'),('bookings','charging_sessions','1 : 0..1'),('charging_sessions','payments','1 : 0..1')]
diagram('relational.png',boxes,edges)
cb={k:(x,y,t,ls[:3]) for k,(x,y,t,ls) in boxes.items()}
diagram('chen.png',cb,[(a,b,label) for (a,b,_),label in zip(edges,['makes','contains','receives','produces','bills'])],True)
diagram('architecture.png',{'a':(430,300,'MYSQL WORKBENCH',['SQL editor and result grids']),'b':(1350,300,'MYSQL SERVER',['Procedures and transactions']),'c':(1350,900,'INNODB TABLES',['Keys, checks and indexes']),'d':(430,900,'REPORTING',['Views and demonstration queries'])},[('a','b','SQL'),('b','c','Read / write'),('c','d','SELECT'),('d','a','Results')])
doc.add_paragraph('EV Charging Station\nManagement System','Title')
p('Project Based Learning Report\nDatabase Management System\nAcademic Year 2026–2027  |  Semester I')
p('Submitted by\n[Student name]\n[Roll number]  |  [Registration number]')
p('Under the guidance of\n[Faculty guide name and designation]')
p('[Department name]\n[College or university name]')
p('A MySQL database study covering design, implementation, operation and evaluation')
h('Certificate')
p('Certificate text for institutional review')
p('This report titled EV Charging Station Management System is submitted by [Student name], [Roll number], to [Department] at [Institution] for the Database Management System Project Based Learning requirement, Semester I, academic year 2026–2027. Certification of the work is reserved for the designated institutional authorities.')
p('Faculty guide signature ____________________\nHead of department signature ____________________\nDate ____________________  Place ____________________')
h('Declaration')
p('I, [Student name], submit this report describing the EV Charging Station Management System. I will confirm the authorship, acknowledge assistance and sources, and comply with my institution’s declaration requirements before signing. The report distinguishes inspected SQL source from historical result records and does not represent unexecuted checks as fresh database tests.')
p('Student signature ____________________\nDate ____________________')
h('Acknowledgement')
p('I thank [Faculty guide name] and [Department name] for their academic support. The MySQL reference documentation provided the technical basis for understanding table definitions and locking reads. Specific contributions and institutional acknowledgements should be confirmed by the student before submission.')
h('Abstract')
p('The EV Charging Station Management System organizes charging infrastructure, reservations, charging activity and payment records in a relational database. Six core tables separate user identities, stations, chargers, bookings, sessions and payments. Primary keys identify records; foreign keys preserve their relationships; unique and check constraints restrict invalid data. Six stored procedures implement booking, session initiation, completion, bill calculation, payment updates and station reporting. Four triggers support time validation, rate capture and status synchronization, while five views expose operational and financial information. The implementation uses MySQL SQL and InnoDB and is intended for demonstration through MySQL Workbench. This report explains the schema, normalization assumptions, complete SQL source and a reproducible operating sequence. Existing testing summaries are treated as historical project records rather than new execution evidence. Static review identifies limitations in summary counting, procedural enforcement and sample data consistency. The project demonstrates how relational modeling and transactions support a charging workflow while exposing the additional validation required for deployment.')
p('Keywords: relational database; MySQL; electric vehicle charging; normalization; transactions; SQL')
h('Contents')
fld=OxmlElement('w:fldSimple'); fld.set(qn('w:instr'),'TOC \\o "1-2" \\h \\z \\u'); doc.add_paragraph()._p.append(fld)
h('1 Introduction')
p('A charging facility must distinguish the location of a station from the individual chargers installed there. A driver reserves one charger for a time interval, but the actual energy delivered is known only after charging. Payment records then describe the invoice and its settlement state. Combining these facts in one spreadsheet repeats identities and infrastructure details and makes changes difficult to reconcile.')
h('1.1 Problem statement and objectives',2)
p('The problem is to maintain a consistent chain from a user reservation to charging consumption and payment without losing the identity of the charger or its station. The project objectives are to model these facts explicitly, validate keys and domains, support reservation checks, preserve a session tariff, calculate bills and provide query based reports. These objectives are evaluated against the SQL source and the evidence available in the project directory.')
h('1.2 Scope and report organization',2)
p('The scope is a local SQL focused academic system. There is no implemented website, mobile application, live energy meter or payment gateway in the supplied project. Chapters 2 and 3 explain analysis and requirements; Chapters 4 and 5 establish the design; Chapter 6 explains operation and implementation; Chapter 7 evaluates evidence; Chapters 8 and 9 describe limitations and conclusions. The appendices reproduce every supplied SQL script, including all 32 demonstration queries.')
h('2 Literature Review and System Analysis')
p('The technical review uses the official MySQL reference manual. CREATE TABLE documentation describes the declarations used for keys, column domains and constraints [1]. The InnoDB locking read documentation explains SELECT FOR UPDATE and its transaction context [2]. These mechanisms inform the source analysis below; their availability does not establish that every application invariant is enforced correctly. No unsupported EV adoption statistics or invented research studies are used.')
table(['Concern','Manual records','Implemented database approach'],[['Identity','Repeated names and contact details','Surrogate IDs and unique user email'],['Infrastructure','Station and charger facts mixed','Separate stations and chargers'],['Reservations','Conflicts require manual comparison','Procedure compares time intervals'],['Billing','Current tariff may replace history','Session stores its captured tariff'],['Reporting','Repeated spreadsheet consolidation','Joins, views and aggregate queries']])
p('Separating infrastructure from activity allows a station to exist before its first booking. Foreign keys prevent references to nonexistent parents, but they do not establish that a charger is operational or that time windows do not overlap. Those business rules require additional procedural checks.')
h('3 Requirement Analysis')
table(['Requirement','Implementation','Verification boundary'],[['User and station management','users and stations tables','DDL inspected'],['Charger management','chargers and operational status','DDL inspected'],['Booking management','sp_book_charger_slot','Source inspected; no fresh run'],['Session tracking','start and complete procedures','No hardware integration'],['Billing and payment','rate snapshot and payment procedures','Recorded status only'],['Reporting','5 views and 32 demo queries','Saved outputs require reconciliation']])
h('3.1 Quality and environment requirements',2)
p('Integrity requires valid references, positive charger power, nonnegative prices and sensible times. Reliability depends on transactions and error handling. Maintainability comes from separate SQL modules. Performance is supported by six explicit indexes, but no timing benchmark is available. Security requires an appropriately restricted database account; the source does not define a complete role or authentication system. Scalability has not been load tested.')
p('The supplied project specifies MySQL Community Server and MySQL Workbench on Windows. Existing result files name MySQL 8.4.13 LTS; that version was not independently checked on a live server for this report. Hardware specifications were not provided. A working MySQL installation, an authorized account, and enough storage for the small sample dataset are required. The design is feasible as a classroom database demonstration; deployment feasibility would require operational and security testing.')
h('4 System Design')
h('4.1 Architecture and workflow',2)
figure('architecture.png','Figure 1 Database centered architecture')
p('The operator issues SQL through Workbench or the MySQL command line. Procedures coordinate writes; InnoDB stores the related records; views and queries return tabular results. The workflow is user registration, station and charger selection, reservation, session start, session completion, invoice generation and payment status recording. Starting a session captures the charger rate; completing it calculates ROUND(energy_kwh × rate_per_kwh, 2).')
h('4.2 Conceptual entity relationship model',2)
figure('chen.png','Figure 2 Chen style ER overview with representative attributes')
p('Rectangles denote entities, ovals denote attributes and diamonds denote relationships. Underlined attributes are primary keys. Exact cardinalities appear in the relationship table and relational diagram. Only representative attributes appear in this overview to preserve readability; the full attribute specification follows. Users make bookings; stations contain chargers; chargers receive bookings; bookings produce sessions; sessions receive payments.')
table(['Parent','Child','Meaning'],[[a,b,c] for a,b,c in edges])
p('Each child refers to exactly one parent through a nonnullable foreign key. A parent may have no children. Unique booking_id in charging_sessions permits at most one session per booking; unique session_id in payments permits at most one payment record per session. These are optional one to one relationships, not mandatory pairs.')
h('4.3 Relational schema',2)
figure('relational.png','Figure 3 Complete relational schema and cardinalities')
h('4.4 Data dictionary',2)
purposes=['Registered drivers and contact information','Station locations','Individual charging units and current prices','Scheduled reservations','Actual charging records and captured prices','Invoices and payment state']
for (name,attrs),purpose in zip(entities.items(),purposes):
 h(name,3); p(purpose+'.')
 table(['Attribute','SQL type','Nullability and constraints'],[(a,b,c.strip().rstrip(',')) for a,b,c in attrs])
p('Foreign keys are chargers.station_id to stations; bookings.user_id to users; bookings.charger_id to chargers; charging_sessions.booking_id to bookings; payments.session_id to charging_sessions. All use ON DELETE RESTRICT and ON UPDATE CASCADE. Charger labels are unique within a station through UNIQUE(station_id, charger_code). CHECK clauses validate email shape with LIKE, positive power, nonnegative rates and amounts, booking end after start, and optional session time and energy values. The email check is a simple shape test, not full email validation.')
h('5 Database Normalization')
h('5.1 Worked decomposition example',2)
p('For teaching purposes, suppose a charging log contains BookingID, ChargerID, StationID, StationName and a repeating list of users with their names. This is a hypothetical starting point rather than a claim about the project’s development history. Flattening the list gives one row per (BookingID, UserID), with scalar values: BookingID, UserID, UserName, ChargerID, StationID, StationName. Assume BookingID identifies a booking and UserID identifies a user.')
p('In 1NF the values are atomic, but UserID determines UserName and BookingID determines ChargerID. Both determinants are proper subsets of the composite key. To reach 2NF, separate User(UserID, UserName), Participation(BookingID, UserID) and Booking(BookingID, ChargerID, StationID, StationName). The last relation still has ChargerID → StationID and StationID → StationName. For 3NF, move these facts into Charger(ChargerID, StationID) and Station(StationID, StationName), leaving Booking(BookingID, ChargerID). Joining the relations through their keys reconstructs the facts under the stated dependencies. The actual project permits exactly one user per booking, so its bookings table stores user_id directly instead of a participation relation.')
h('5.2 Assessment of the implemented schema',2)
table(['Relation','Candidate keys','Dependency assessment'],[['users','user_id; email','Each determines all other attributes'],['stations','station_id','Names are not declared unique'],['chargers','charger_id; station_id + charger_code','No declared partial dependency'],['bookings','booking_id','Determines user, charger and interval'],['charging_sessions','session_id; booking_id','Both determine session facts'],['payments','payment_id; session_id','Both determine payment facts']])
p('Under the modeled dependencies, each relation is in 3NF. Single column surrogate keys alone do not prove normalization; the candidate keys and nonkey dependencies must also be considered. No city → state dependency is assumed because city names need not uniquely identify jurisdictions. Separating session and payment records also expresses different lifecycle states and optional participation; a one to one relationship alone is not proof of a transitive dependency violation.')
p('The session price is a historical fact distinct from the current charger catalog price. Storing both therefore serves different meanings. The payment amount is calculated and stored for the invoice, but no constraint continuously reconciles it with session energy and price. The design reduces repeated station and user details and avoids losing their records when a booking is deleted. It does not provide an immutable financial ledger.')
h('6 Database Implementation and User Guide')
h('6.1 Installation and safe setup',2)
p('Use a fresh disposable project database for initial setup. The seed file truncates all six core tables, and the master setup sources that file. It must not be rerun against data that needs to be retained. The index script is not idempotent because CREATE INDEX repeats existing index names. No setup or test script was executed while preparing this report.')
p('In MySQL Workbench, open an authorized connection. Use File > Open SQL Script to open and execute 01_create_database.sql, 02_create_tables.sql, 03_constraints_indexes.sql, 04_triggers.sql, 05_stored_procedures.sql and 06_views.sql in that order. Only for a fresh demonstration dataset, execute 03_Sample_Data/01_seed_data.sql next. Refresh the Schemas panel, expand ev_charging_management, and inspect Tables, Views and Stored Procedures. SOURCE is a mysql client command; execute component files individually in Workbench.')
p('For the mysql command line, start the client from the project root with mysql -u YOUR_USER -p, enter the password at the prompt, and run the following command only for a fresh demonstration installation:')
code('SOURCE 02_SQL_Scripts/08_full_project_setup.sql;')
code('USE ev_charging_management;\nSELECT DATABASE(), VERSION();\nSHOW TABLES;\nSHOW PROCEDURE STATUS WHERE Db = DATABASE();\nSHOW TRIGGERS;\nSELECT * FROM vw_active_chargers;')
h('6.2 Demonstrating the complete workflow',2)
p('The following calls are executable examples for a disposable demonstration database, not actions performed during report preparation. Confirm user 1 and charger 2 exist and that the selected interval is free. Run one call at a time and inspect the returned status before continuing. The session procedure uses CURRENT_TIMESTAMP and does not enforce the scheduled start window.')
code("CALL sp_book_charger_slot(1, 2,\n '2026-11-21 10:00:00', '2026-11-21 11:00:00',\n @booking, @status, @message);\nSELECT @booking, @status, @message;\n-- Continue only when @status = 'SUCCESS'.\nCALL sp_start_charging_session(@booking,\n @session, @status, @message);\nSELECT @session, @status, @message;\n-- Continue only when @status = 'SUCCESS'.\nCALL sp_complete_charging_session(@session, 10.000,\n @amount, @status, @message);\nSELECT @amount, @status, @message;\nCALL sp_process_payment(@session, 'UPI', 'COMPLETED',\n @status, @message);\nSELECT @status, @message;\nSELECT * FROM vw_payment_audit_log\nWHERE session_id = @session;")
p('Expected behavior, not newly executed output: booking creates a confirmed reservation; start creates one session; completion records energy and a pending payment; payment processing records the requested settlement state. This records a demonstration payment and does not contact a bank. If any call fails, stop the sequence and inspect its message.')
h('6.3 Basic data operations',2)
p('The following optional practice transaction illustrates INSERT, SELECT, UPDATE and DELETE without leaving the new user record behind. It must be run in one connection. Do not wrap the workflow procedures in this transaction because those procedures manage their own transaction boundaries.')
code("START TRANSACTION;\nINSERT INTO users(full_name,email,phone)\nVALUES ('Report Demo','report.demo@example.in','9000000000');\nSET @demo = LAST_INSERT_ID();\nSELECT * FROM users WHERE user_id = @demo;\nUPDATE users SET phone = '9000000001' WHERE user_id = @demo;\nDELETE FROM users WHERE user_id = @demo;\nROLLBACK;")
h('6.4 Procedures triggers and indexes',2)
p('sp_book_charger_slot validates the user, locks the charger row, checks its operational state and rejects intersecting pending or confirmed intervals. Two half open intervals overlap when existing.start < requested.end and requested.start < existing.end. Adjacent slots are permitted. The row lock coordinates callers using the same procedure, but simultaneous session testing remains necessary: the earlier plain user lookup may establish a repeatable read snapshot before a competing booking commits. Absolute concurrency safety is not established by the saved sequential test.')
p('sp_start_charging_session checks booking status and captures the tariff. sp_complete_charging_session records energy, updates the session and creates or updates a pending invoice. sp_calculate_bill joins the user, booking, charger and station to return bill details. sp_process_payment updates a payment state. sp_station_revenue_report summarizes stations. Exceptions in transaction routines invoke rollback and return an error code.')
p('The four triggers validate inserted booking times, supply a session rate when nonpositive or missing, synchronize booking completion after a session status update, and supply payment timestamps on transition to completed. There is no overlap trigger, no tariff immutability trigger and no automatic invoice creation for a directly inserted completed session. Indexes cover geographic lookup, charger status/type, booking conflict search, user history, session status/date and payment status/method.')
h('6.5 Query reading guide',2)
p('Queries 1–5 demonstrate selection, filtering, DISTINCT and ordering. Queries 6–10 use inner and left joins to expose relationships and missing activity. Query 11 combines COUNT, SUM, AVG, MIN and MAX with GROUP BY; Query 15 uses HAVING to filter groups. Queries 16–20 introduce scalar, correlated and EXISTS subqueries. Queries 21–24 use a CTE and window functions. Query 25 requests an execution plan. Queries 26–32 demonstrate views, interval lookup and procedure based reporting. The full text of every query is in Appendix G.')
p('Interpret query labels carefully: Query 16 compares prices per kWh, not hourly rates. Query 20 measures the fraction of operational chargers rather than time based utilization. Query 26 lists operational chargers but does not check reservation availability. Query 27 checks reservation overlap but does not filter charger status. Query 21 groups paid sessions by session start month rather than payment settlement month. A plan showing an index is evidence of an access path, not measured latency.')
h('6.6 Troubleshooting',2)
table(['Symptom','Interpretation and response'],[['Unknown database or table','Run creation scripts in dependency order and select the schema'],['Duplicate index name','Index script has already run; inspect SHOW INDEX instead of rerunning'],['SLOT_CONFLICT','Choose a free interval and inspect existing bookings'],['CHARGER_UNAVAILABLE','Select an ACTIVE charger'],['SESSION_ALREADY_EXISTS','Inspect the existing session rather than starting another'],['Foreign key deletion error','A dependent record exists; retain history or use a disposable test copy'],['Unexpected result totals','Check seed state, status filters and join multiplicity']])
h('7 Results and Testing')
p('Evidence is divided into inspected SQL, saved historical summaries and newly calculated static checks. No live MySQL connection was used for this report. The saved Test_Summary.md claims 20 of 20 passing tests, and Test_Results.md claims 32 successful queries. These statements are retained as historical claims, not independent verification. Several discrepancies prevent treating those files as a verified current snapshot.')
h('7.1 Seed data and reproducible results',2)
seed=(ROOT/'03_Sample_Data/01_seed_data.sql').read_text(encoding='utf-8-sig')
data={}
import ast
clean=re.sub(r'--[^\n]*','',seed)
for name,cols,vals in re.findall(r'INSERT INTO (\w+) \((.*?)\) VALUES\s*(.*?);',clean,re.S):
 rows=ast.literal_eval('['+re.sub(r'\bNULL\b','None',vals)+']'); data[name]=[dict(zip([c.strip() for c in cols.split(',')],r)) for r in rows]
table(['Table','Rows in seed source'],[(k,len(v)) for k,v in data.items()])
paid=[r for r in data['payments'] if r['status']=='COMPLETED']
total=sum(Decimal(str(r['amount'])) for r in paid)
p(f'Static recomputation from seed INSERT values gives {len(paid)} completed payments totaling INR {total:,.2f}. This calculation does not execute MySQL. Session 1 contains 42.500 kWh at INR 19.50 per kWh; its calculated bill is INR 828.75 and the seed payment matches.')
p('The saved monthly output instead reports INR 18,942.28. It therefore does not match the supplied seed source. This report uses the recomputed source total and does not reproduce the conflicting saved output as verified evidence.')
table(['Check','Source observation','Assessment'],[['Pending payment count','Seed contains 3; saved grouping says 2','Saved output inconsistent'],['Session state','Bookings 28–30 completed while sessions in progress','Cross table state mismatch'],['Missing invoices','Completed sessions 26–27 lack payments','Allowed by optional FK cardinality'],['Operational charger count','SUM after one to many booking join','May count a charger repeatedly'],['TC 19 assertion','Checks existence of positive revenue','Does not prove equality of totals'],['TC 20 assertion','Writes PASS after cleanup','Does not assert absence of remaining records']])
h('7.2 Test coverage and evidence status',2)
tests=[('Valid user','Insert accepted'),('Duplicate email','Unique constraint rejection'),('Malformed email','LIKE check rejection'),('Orphan charger','Foreign key rejection'),('Nonpositive power','CHECK rejection'),('Reversed booking times','Rejected'),('Maintenance charger','CHARGER_UNAVAILABLE'),('Valid booking','SUCCESS'),('Overlapping slot','SLOT_CONFLICT'),('Adjacent slot','SUCCESS'),('Session start','Tariff captured'),('Duplicate session','Rejected'),('Negative energy','Rejected'),('Session completion','Correct rounded invoice'),('Catalog price change','Existing session price unchanged'),('Duplicate payment','Unique constraint rejection'),('Payment completion','Timestamp recorded'),('Delete parent station','RESTRICT rejection'),('View aggregation','Independent total reconciliation'),('Cleanup','No disposable records remain')]
table(['Test','Objective','Expected','Current verification'],[(f'TC-{i:02}',a,b,'NOT EXECUTED; saved PASS claim') for i,(a,b) in enumerate(tests,1)])
p('The test harness is a separate module that creates test_execution_log and sp_run_automated_tests. Therefore six tables describes the core model, not every table that could exist after testing. Its cleanup targets qa.% user emails and its script drops the existing log table. Run it only on a disposable copy after reviewing the affected records. It was not run for report production. Negative cases should assert specific error codes, concurrent booking tests need two independent connections, and reporting tests should compare independently computed totals.')
h('8 Advantages Limitations and Future Scope')
p('The design offers a traceable chain of identifiers, reduced repetition, configurable charger prices and reusable reporting queries. Decimal types support explicit monetary rounding. Unique session and payment foreign keys prevent duplicate records for the same parent. Separating operational status from booking intervals is useful, provided callers check both.')
p('Limitations include direct SQL bypass of procedure rules, editable historical tariffs and invoice amounts, no live hardware or banking connection, incomplete lifecycle validation and unverified concurrency behavior. The start procedure does not enforce booking times or recheck charger availability. The aggregate view can overcount operational chargers. Seed data has lifecycle inconsistencies, and historical test summaries overstate the strength of some assertions. These are documented findings; the implementation files were not changed.')
p('Future work should first strengthen database validation and tests, correct summary counting and reconcile the seed dataset. Later extensions can add a web interface, authenticated roles, hardware status ingestion, map search, gateway integration and notifications. Utilization analytics should measure occupied time explicitly. Predictive availability and smart scheduling are proposals requiring data and evaluation, not implemented features.')
h('9 Conclusion')
p('The project models the principal records of an EV charging workflow with six related tables, stored procedures, triggers, indexes and reporting views. The schema supports a justified 3NF interpretation under its stated dependencies and separates current charger prices from session price snapshots. The complete SQL package provides a practical basis for demonstrating relational design, joins, aggregation and transactions. Static inspection confirms the implementation structure while identifying limits in procedural enforcement, sample consistency and test assertions. The report therefore documents a substantive academic database implementation without claiming production readiness or independently verified live test success.')
h('References')
p('[1] Oracle. MySQL 8.4 Reference Manual, CREATE TABLE Statement. Consulted 15 November 2026. https://dev.mysql.com/doc/refman/8.4/en/create-table.html')
p('[2] Oracle. MySQL 8.4 Reference Manual, Locking Reads. Consulted 15 November 2026. https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html')
p('[3] Project implementation sources: 02_SQL_Scripts, 03_Sample_Data and 07_Testing/Test_Cases.sql. Local project files inspected for this report.')
p('[4] Historical project evidence: 04_Query_Results/Test_Results.md and 07_Testing/Test_Summary.md. Their claims are subject to the discrepancies documented in Chapter 7.')
files=sorted((ROOT/'02_SQL_Scripts').glob('*.sql'))+list((ROOT/'03_Sample_Data').glob('*.sql'))+list((ROOT/'07_Testing').glob('*.sql'))
for i,file in enumerate(files):
 h(f'Appendix {chr(65+i)} '+file.stem.replace('_',' '))
 p('Source: '+str(file.relative_to(ROOT))+'. Complete listing reproduced for reference; original comments are source annotations and do not override the limitations discussed in Chapters 6 and 7.')
 code(file.read_text(encoding='utf-8-sig'))
doc.save(OUT/'EV_Charging_Station_Management_PBL_Report.docx')
(OUT/'Report_Source.md').write_text('\n'.join(md),encoding='utf-8')
(OUT/'Report_Validation.md').write_text('# Report validation\n\nCollege template not found in workspace; academic fallback used. Student, guide, department and institution details require completion. Certificate and declaration require institutional review.\n\nAll SQL files reproduced verbatim except visual line wrapping. Six core tables, four triggers, six procedures, five views and all 32 demonstration queries documented. Test module additionally creates a log table and test procedure. No database writes or live tests performed. Historical PASS claims are not fresh verification. Seed values statically parsed and payment totals recomputed.\n\nDiagrams generated from actual table columns: Chen overview with representative attributes, full relational schema, and architecture.\n\nSource files inspected: '+', '.join(str(x.relative_to(ROOT)) for x in files)+'; database design documentation; original report; historical result and test summaries.\n\nDocument rendering and page QA: pending.\n',encoding='utf-8')
print(OUT)
