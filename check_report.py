from pathlib import Path
import fitz
from PIL import Image,ImageDraw
p=Path('05_Project_Report/Final_Submission')
d=fitz.open(p/'EV_Charging_Station_Management_PBL_Report.pdf')
qa=p/'qa';qa.mkdir(exist_ok=True)
for start in range(0,len(d),16):
 canvas=Image.new('RGB',(1200,1680),'#cccccc'); draw=ImageDraw.Draw(canvas)
 for j in range(start,min(start+16,len(d))):
  pg=d[j]; pix=pg.get_pixmap(matrix=fitz.Matrix(.48,.48)); im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples); im.thumbnail((290,390))
  x=(j-start)%4*300;y=(j-start)//4*420;canvas.paste(im,(x,y+20));draw.text((x+10,y+3),str(j+1),fill='black')
 canvas.save(qa/f'contact-{start//16+1}.png')
print('Pages',len(d))
print('Short pages',[(i+1,len(pg.get_text())) for i,pg in enumerate(d) if len(pg.get_text())<100])
print(d[5].get_text()[:1500])
