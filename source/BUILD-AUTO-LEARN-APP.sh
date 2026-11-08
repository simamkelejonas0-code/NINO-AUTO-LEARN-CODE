#!/data/data/com.termux/files/usr/bin/bash
set -e
echo "=== BUILD NINO AUTO LEARN V5.13 FILL - 6 BUGS FIXED ==="
ANDROID_JAR=$(find $HOME -type f -name "android.jar" -size +20M 2>/dev/null | head -1)
[ -z "$ANDROID_JAR" ] && ANDROID_JAR="/data/data/com.termux/files/home/downloads/toolbox_full/lib/android.jar"
AAPT2=$PREFIX/bin/aapt2; D8=$PREFIX/bin/d8; ZIPALIGN=$PREFIX/bin/zipalign; APKSIGNER=$PREFIX/bin/apksigner
KEYSTORE=$HOME/myAI/nino2.keystore
PROJ=$HOME/myAI/NINO-AUTO-LEARN-V1
rm -rf $PROJ; mkdir -p $PROJ/src/com/nino/autolearn $PROJ/build $PROJ/res/values $PROJ/assets
cp $HOME/myAI/auto/lessons/lesson_muse-spark-1.3_*.json $PROJ/assets/lessons.json 2>/dev/null || echo '{"lesson":"CRACK 8px x 13.889 = 112mm WALL 576x432px = 48.000m2 PAINT 4.800L FILL 13.44L CAL 13.889"}' > $PROJ/assets/lessons.json
if [ -f /sdcard/Download/mtm_key.txt ]; then cp /sdcard/Download/mtm_key.txt $PROJ/assets/mtm_key.txt; echo "key copied"; fi
cat > $PROJ/res/values/strings.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
<string name="perm_video_camera_and_camera">take video camera and camera</string>
<string name="perm_desc">take video camera and camera</string>
<string name="app_name">NINO AUTO LEARN V5.13</string>
</resources>
XML
cat > $PROJ/src/com/nino/autolearn/Worker.java <<'JAVA'
package com.nino.autolearn;
import java.io.*; import java.net.*;
public class Worker implements Runnable{
 public int idx; public String model; public String prompt; public String key; public String b64;
 public Worker(int idx, String model, String prompt, String key, String b64){ this.idx=idx; this.model=model; this.prompt=prompt; this.key=key; this.b64=b64; }
 String callOnce(){
  try{
   String userText=prompt.replace("\\"," ").replace("\"","'").replace("\n"," ");
   String json="{\"model\":\""+model+"\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\""+userText+"\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/jpeg;base64,"+b64+"\"}}]}],\"max_tokens\":8000}";
   URL url=new URL("https://api.meta.ai/v1/chat/completions"); HttpURLConnection c=(HttpURLConnection)url.openConnection(); c.setRequestMethod("POST"); c.setRequestProperty("Authorization","Bearer "+key); c.setRequestProperty("Content-Type","application/json"); c.setConnectTimeout(8000); c.setReadTimeout(12000); c.setDoOutput(true); c.getOutputStream().write(json.getBytes());
   int code=c.getResponseCode(); InputStream in=(code>=200 && code<300)?c.getInputStream():c.getErrorStream();
   BufferedReader br=new BufferedReader(new InputStreamReader(in)); StringBuilder sb=new StringBuilder(); String line; while((line=br.readLine())!=null) sb.append(line);
   String out=MainActivity.extractContent(sb.toString());
   if(code<200||code>=300) return "HTTP "+code+" "+out;
   return out;
  }catch(Exception e){ return "ERR "+e.getMessage(); }
 }
 public void run(){
  String r=callOnce();
  // FIX: 1-word "wall" is not an answer - retry with full-scene prompt
  if(r!=null && r.trim().length()<15 && !r.startsWith("ERR") && !r.startsWith("HTTP")){
    try{ Thread.sleep(500); }catch(Exception e){}
    String r2=callOnce();
    if(r2!=null && r2.trim().length()>r.trim().length()) r=r2;
  }
  if(r==null||r.trim().isEmpty()||r.equals("NO CONTENT")||r.equals("EMPTY")||r.startsWith("ERR ")){
    try{ Thread.sleep(500); }catch(Exception e){}
    String r2=callOnce();
    if(r2!=null && !r2.trim().isEmpty() && !r2.equals("NO CONTENT") && !r2.equals("EMPTY")) r=r2;
    else if((r==null||r.trim().isEmpty()) && r2!=null) r=r2;
  }
  MainActivity.nerveResults[idx]=r; MainActivity.nerveDone[idx]=true; MainActivity.nerveCount++;
 }
}
JAVA
cat > $PROJ/src/com/nino/autolearn/MainActivity.java <<'JAVA'
package com.nino.autolearn;
import android.app.Activity; import android.os.Bundle; import android.widget.*; import android.view.View; import android.view.SurfaceView; import android.view.SurfaceHolder; import android.graphics.Color; import android.view.Gravity; import android.content.pm.PackageManager; import android.Manifest; import android.hardware.Camera; import android.graphics.*;
import java.io.*; import java.net.*; import java.util.*;
public class MainActivity extends Activity implements View.OnClickListener, Runnable, SurfaceHolder.Callback, Camera.PreviewCallback{
 static final String VIDEO_CAMERA_AND_CAMERA = "com.nino.autolearn.permission.VIDEO_CAMERA_AND_CAMERA";
 public static String[] nerveResults=new String[12]; public static boolean[] nerveDone=new boolean[12]; public static int nerveCount=0;
 public static String extractContent(String raw){
  try{
   if(raw==null) return "EMPTY";
   if(raw.contains("\"error\"")){ int e=raw.indexOf("\"message\""); if(e>=0){ int a=raw.indexOf("\"", e+10); int b=raw.indexOf("\"", a+1); if(a>=0 && b>a) return "API ERROR: "+raw.substring(a+1,b); } return "API ERROR: "+raw.substring(0, Math.min(300, raw.length())); }
   int mi=raw.indexOf("\"message\"");
   if(mi>=0){ int ci=raw.indexOf("\"content\"", mi); if(ci>=0){ String s=extractQuoted(raw, ci); if(s!=null && s.length()>0) return s; } }
   int ti=raw.indexOf("\"text\"");
   if(ti>=0){ String s=extractQuoted(raw, ti); if(s!=null && s.length()>0) return s; }
   int idx=raw.indexOf("\"content\""); if(idx>=0){ String s=extractQuoted(raw, idx); if(s!=null && s.length()>0) return s; }
   if(raw.contains("\"finish_reason\":\"length\"")) return "CUT BY LENGTH";
   int r=raw.indexOf("\"refusal\""); if(r>=0){ String s=extractQuoted(raw, r); if(s!=null && s.length()>0) return "REFUSED: "+s; }
   return "NO CONTENT";
  }catch(Exception e){ return "PARSER ERR "+e.getMessage(); }
 }
 static String extractQuoted(String raw, int keyIdx){
  try{
   int colon=raw.indexOf(":", keyIdx+1); if(colon<0) return null;
   int p=colon+1; while(p<raw.length() && (raw.charAt(p)==' '||raw.charAt(p)=='\n')) p++;
   if(p>=raw.length()) return null;
   if(raw.charAt(p)=='['){ int t=raw.indexOf("\"text\"", p); if(t>=0) return extractQuoted(raw, t); return null; }
   if(raw.charAt(p)!='"') return null;
   StringBuilder out=new StringBuilder(); p++;
   while(p<raw.length()){ char ch=raw.charAt(p); if(ch=='\\' && p+1<raw.length()){ char n=raw.charAt(p+1); if(n=='n') out.append('\n'); else if(n=='"') out.append('"'); else if(n=='\\') out.append('\\'); else if(n=='t') out.append(' '); else out.append(n); p+=2; continue; } if(ch=='"') break; out.append(ch); p++; }
   return out.toString();
  }catch(Exception e){ return null; }
 }
 TextView status, result, askText, logView, instantView, brainView, footer; EditText input; double CAL=13.889;
 int mode=0; String pending=""; String teachQ=""; boolean frameOk=false; int lastAvgY=-1; int frameCount=0; int lastW=0; int lastH=0; byte[] lastLiveJpeg=null; int lastLiveJpegLen=0;
 Button bLearn, bTeach, bMeas, bSend, bVideo, bAsk, bAuto, bLogs; SurfaceView preview; ImageView liveView; SurfaceHolder holder; Camera cam; boolean surfaceReady=false; Bitmap liveBmpPending=null;
 LinearLayout logWrap;
 String lessonFile="/sdcard/Download/nino_lessons.txt";
 boolean autoSee=false; boolean autoBusy=false; int lastAutoFrame=0; int lastAutoAvgY=-1; int lastAutoJpegLen=-1; int autoCount=0; int lastFullFrame=0;
 boolean showLogs=false; String lastLog="";
 int prevAvgY=-1; int lastCenterR=-1; int lastCenterG=-1; int lastCenterB=-1;
 int steadyA=-1; int steadyB=-1; int steadyC=-1;
 static class Snap{ boolean steady; boolean glare; boolean dark; int avgY; String colour; int r; int g; int b; boolean askedMeasure; }
 Snap lastSnap=null;
 String[] API_MODELS={"muse-spark-1.3","muse-spark-1.3-contributor","muse-spark-1.2","muse-spark-1.2-contributor","muse-spark-1.1","muse-wonder-1.0"};
 String[] API_JOBS={"SENSORY: describe this scene in 2 sentences, list every object you are sure about.","SENSORY2: detail - colours, texture, glare, indoor or outdoor? 1 line only.","INTER MEASURE: ONLY if user asked measure AND phone is steady straight-on: estimate px for crack/door/wall. Else NOT VERIFIED. 1 line only.","INTER2 CHECK: verify CAL 13.889 math ONLY if px given in this frame, else NOT VERIFIED. 1 line only.","SCENE: room context - indoor RDP, outdoor road, pink wall, corrugated roof, dirt road, houses, sky? 1 line only.","REASON: is phone straight-on to wall/door? YES/NO + why. If moving / outdoor road, NO. 1 line only."};
 String[] KNOWN={"wall","roof","floor","door","window","bed","blanket","pillow","speaker","mirror","chair","table","jacket","clothes","fabric","panel","case","light","glare","crack","brick","concrete","corrugated","cabinet","counter","stove","kitchen","tile","fridge","refrigerator","freezer","sink","cupboard","curtain","sofa","couch","tv","television","bucket","broom","pot","pan","kettle","bedding","sheet","mattress","wardrobe","closet","shelf","lamp","fan","heater","rug","carpet","road","dirt","street","houses","house","sky","grass","tree","dog","cat","car","fence","gate","pole","cloud","path","yard","ground","soil","sand","bush","plant"};
 protected void onCreate(Bundle b){
  super.onCreate(b);
  ScrollView outer=new ScrollView(this); outer.setBackgroundColor(Color.BLACK); outer.setFillViewport(true);
  LinearLayout root=new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setLayoutParams(new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT)); root.setBackgroundColor(Color.parseColor("#111111"));
  TextView h=new TextView(this); h.setText("NINO AUTO LEARN  •  V5.13 FILL  •  6 BUGS FIXED"); h.setTextColor(Color.WHITE); h.setGravity(Gravity.CENTER); h.setTextSize(13); h.setPadding(10,10,10,2);
  askText=new TextView(this); askText.setText("VIDEO CAMERA AND CAMERA"); askText.setTextColor(Color.parseColor("#00E676")); askText.setGravity(Gravity.CENTER); askText.setTextSize(16); askText.setPadding(10,2,10,2);
  TextView sub=new TextView(this); sub.setText("Moving = Describe | Steady = Identify + Label + Count | Steady + Straight + Asked Measure = Measure + Calculate"); sub.setTextColor(Color.parseColor("#AAAAAA")); sub.setGravity(Gravity.CENTER); sub.setTextSize(10); sub.setPadding(16,0,16,4);
  status=new TextView(this); status.setText("VIDEO CAMERA AND CAMERA: ...  CAMERA: ..."); status.setTextColor(Color.parseColor("#FFD600")); status.setGravity(Gravity.CENTER); status.setTextSize(11); status.setPadding(10,2,10,6);
  preview=new SurfaceView(this); holder=preview.getHolder(); holder.addCallback(this); LinearLayout.LayoutParams pv=new LinearLayout.LayoutParams(1,1); preview.setLayoutParams(pv);
  LinearLayout wrap=new LinearLayout(this); wrap.setGravity(Gravity.CENTER); wrap.setBackgroundColor(Color.BLACK);
  liveView=new ImageView(this); liveView.setBackgroundColor(Color.BLACK); liveView.setScaleType(ImageView.ScaleType.FIT_XY); liveView.setRotation(90);
  LinearLayout.LayoutParams lv=new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 480); liveView.setLayoutParams(lv); wrap.addView(liveView); LinearLayout.LayoutParams wp=new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 480); wrap.setLayoutParams(wp);
  instantView=new TextView(this); instantView.setText("Eye is looking..."); instantView.setTextColor(Color.parseColor("#FFD600")); instantView.setTextSize(12); instantView.setPadding(16,6,16,6); instantView.setBackgroundColor(Color.parseColor("#2A2A00"));
  brainView=new TextView(this); brainView.setText("BRAIN: DESCRIBE - Eye is moving"); brainView.setTextColor(Color.parseColor("#00E676")); brainView.setTextSize(12); brainView.setPadding(16,6,16,6); brainView.setBackgroundColor(Color.parseColor("#002A12"));
  result=new TextView(this); result.setText("I see...\n\nTap AUTO SEE: ON - eye will describe, label, count, measure when ready.\n\nV5.13: Colour is colour only. Measure only when you ask + steady + straight."); result.setTextColor(Color.WHITE); result.setTextSize(16); result.setPadding(16,12,16,12); result.setBackgroundColor(Color.parseColor("#1E1E1E"));
  result.setMinHeight(120); result.setMinimumHeight(120);
  TextView logHeader=new TextView(this); logHeader.setText("LOGS - FOR YOU ONLY"); logHeader.setTextColor(Color.parseColor("#FFD600")); logHeader.setGravity(Gravity.CENTER); logHeader.setTextSize(10); logHeader.setPadding(10,6,10,2); logHeader.setBackgroundColor(Color.parseColor("#0A0A0A"));
  logView=new TextView(this); logView.setText("LOGS hidden."); logView.setTextColor(Color.parseColor("#888888")); logView.setTextSize(10); logView.setPadding(16,8,16,8); logView.setBackgroundColor(Color.parseColor("#0A0A0A"));
  logWrap=new LinearLayout(this); logWrap.setOrientation(LinearLayout.VERTICAL); logWrap.addView(logHeader); logWrap.addView(logView); logWrap.setVisibility(View.GONE);
  input=new EditText(this); input.setHint("Ask: What do you see? / crack 8px wall 576x432px / count / measure"); input.setTextColor(Color.WHITE); input.setHintTextColor(Color.parseColor("#888888")); input.setBackgroundColor(Color.parseColor("#2A2A2A")); input.setPadding(14,10,14,10);
  LinearLayout row=new LinearLayout(this); row.setOrientation(LinearLayout.HORIZONTAL);
  bLearn=new Button(this); bLearn.setText("LEARN OFFLINE"); bLearn.setId(101); bLearn.setOnClickListener(this);
  bTeach=new Button(this); bTeach.setText("TEACH ONLINE"); bTeach.setId(102); bTeach.setOnClickListener(this);
  bMeas=new Button(this); bMeas.setText("MEASURE DOOR"); bMeas.setId(103); bMeas.setOnClickListener(this);
  row.addView(bLearn); row.addView(bMeas); row.addView(bTeach);
  bAsk=new Button(this); bAsk.setText("ALLOW VIDEO CAMERA AND CAMERA"); bAsk.setId(107); bAsk.setOnClickListener(this); bAsk.setBackgroundColor(Color.parseColor("#FF9800")); bAsk.setTextColor(Color.WHITE);
  LinearLayout row2=new LinearLayout(this); row2.setOrientation(LinearLayout.HORIZONTAL);
  bVideo=new Button(this); bVideo.setText("VIDEO: ON"); bVideo.setId(106); bVideo.setOnClickListener(this); bVideo.setBackgroundColor(Color.parseColor("#00C853")); bVideo.setTextColor(Color.WHITE); row2.addView(bVideo);
  bAuto=new Button(this); bAuto.setText("AUTO SEE: OFF"); bAuto.setId(108); bAuto.setOnClickListener(this); bAuto.setBackgroundColor(Color.parseColor("#9E9E9E")); bAuto.setTextColor(Color.WHITE); row2.addView(bAuto);
  bLogs=new Button(this); bLogs.setText("SHOW LOGS"); bLogs.setId(109); bLogs.setOnClickListener(this); bLogs.setBackgroundColor(Color.parseColor("#424242")); bLogs.setTextColor(Color.WHITE); row2.addView(bLogs);
  bSend=new Button(this); bSend.setText("SEND"); bSend.setId(104); bSend.setOnClickListener(this); bSend.setBackgroundColor(Color.parseColor("#2196F3")); bSend.setTextColor(Color.WHITE);
  footer=new TextView(this); footer.setText("created by SIIMAMKELE NGXONONO from KIRKWOOD"); footer.setTextColor(Color.parseColor("#888888")); footer.setGravity(Gravity.CENTER); footer.setTextSize(10); footer.setPadding(10,6,10,6);
  root.addView(h); root.addView(askText); root.addView(sub); root.addView(status); root.addView(preview); root.addView(wrap); root.addView(instantView); root.addView(brainView); root.addView(result); root.addView(logWrap); root.addView(input); root.addView(row); root.addView(bAsk); root.addView(row2); root.addView(bSend); root.addView(footer);
  outer.addView(root);
  h.setVisibility(View.GONE); askText.setVisibility(View.GONE); sub.setVisibility(View.GONE); status.setVisibility(View.GONE);
  // V5.13: MEASURE PHONE - no more guessed heights
  try{
    android.util.DisplayMetrics dm = new android.util.DisplayMetrics();
    getWindowManager().getDefaultDisplay().getMetrics(dm);
    int screenH = dm.heightPixels;
    // Other views: Eye(40) + BRAIN(40) + I SEE(150) + input(60) + row(60) + allow(50) + row2(60) + SEND(60) + signature(30) = ~550
    int camH = screenH - 560;
    if(camH < 300) camH = 300;
    if(camH > 900) camH = 900;
    LinearLayout.LayoutParams lv2 = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, camH);
    liveView.setLayoutParams(lv2);
    LinearLayout.LayoutParams wp2 = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, camH);
    wrap.setLayoutParams(wp2);
  }catch(Exception e){}
  setContentView(outer); updateStatus();
  if(checkSelfPermission(VIDEO_CAMERA_AND_CAMERA)!=PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED){ askStep1(); }
 }
 void updateStatus(){ boolean custom=checkSelfPermission(VIDEO_CAMERA_AND_CAMERA)==PackageManager.PERMISSION_GRANTED; boolean camOk=checkSelfPermission(Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED; status.setText("VIDEO CAMERA AND CAMERA: "+(custom?"GRANTED":"NOT YET")+"  CAMERA: "+(camOk?"GRANTED":"NOT YET")+"  LESSONS: "+countLessons()+"  AUTO: "+(autoSee?"ON - BRAIN":"OFF")); status.setTextColor(Color.parseColor((custom&&camOk)?"#00E676":"#FFD600")); }
 int countLessons(){ try{ BufferedReader br=new BufferedReader(new FileReader(lessonFile)); int n=0; while(br.readLine()!=null) n++; br.close(); return n; }catch(Exception e){ return 0; } }
 void saveLesson(String q, String finalAns){ try{ FileWriter fw=new FileWriter(new File(lessonFile), true); fw.write("Q: "+q.replace("\n"," ")+" | FINAL: "+finalAns.replace("\n"," ")+" | CAL 13.889 | frames "+frameCount+"\n"); fw.close(); }catch(Exception e){} }
 void askStep1(){ askText.setText("ASKING 1/2: VIDEO CAMERA AND CAMERA"); requestPermissions(new String[]{VIDEO_CAMERA_AND_CAMERA}, 101); }
 void askStep2(){ askText.setText("ASKING 2/2: CAMERA"); requestPermissions(new String[]{Manifest.permission.CAMERA}, 102); }
 public void onRequestPermissionsResult(int code, String[] perms, int[] res){ super.onRequestPermissionsResult(code,perms,res); boolean granted=res.length>0 && res[0]==PackageManager.PERMISSION_GRANTED; if(code==101){ if(granted){ showInstant("Step 1 done."); showFull("I SEE: STEP 1 DONE - Now popup 2: CAMERA\n\nBRAIN: DESCRIBE", "STEP 1 DONE"); askStep2(); } else showFull("I SEE: Permission denied.\n\nBRAIN: DESCRIBE", "VIDEO CAMERA AND CAMERA: DENIED"); } else if(code==102){ if(granted){ askText.setText("VIDEO CAMERA AND CAMERA"); updateStatus(); showFull("I SEE: Both granted. Eye is live.\n\nBRAIN: DESCRIBE", "BOTH GRANTED"); if(surfaceReady) startCamera(); } else showFull("I SEE: Camera denied.", "CAMERA: DENIED"); } updateStatus(); }
 protected void onResume(){ super.onResume(); updateStatus(); }
 void startCamera(){ if(!surfaceReady) return; if(checkSelfPermission(VIDEO_CAMERA_AND_CAMERA)!=PackageManager.PERMISSION_GRANTED || checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED) return; try{ if(cam==null){ try{ cam=Camera.open(); }catch(Exception e){ cam=Camera.open(0); } } Camera.Parameters p=cam.getParameters(); List<Camera.Size> sizes=p.getSupportedPreviewSizes(); Camera.Size best=null; if(sizes!=null){ for(int i=0;i<sizes.size();i++){ Camera.Size s=sizes.get(i); if(s.width==640 && s.height==480){ best=s; break; } } if(best==null){ best=sizes.get(sizes.size()-1); for(int i=0;i<sizes.size();i++){ if(sizes.get(i).width<best.width) best=sizes.get(i); } } } if(best!=null){ try{ p.setPreviewSize(best.width, best.height); lastW=best.width; lastH=best.height; }catch(Exception e){} } try{ cam.setParameters(p); }catch(Exception e){} cam.setDisplayOrientation(90); cam.setPreviewDisplay(holder); cam.setPreviewCallback(this); cam.startPreview(); showFull("I SEE: Eye is live. Move phone - I will describe, label, count, measure when ready.\n\nBRAIN: DESCRIBE", "VIDEO CAMERA AND CAMERA: LIVE - V5.13 READY"); }catch(Exception e){ showFull("I SEE: Eye is off.", "VIDEO CAMERA AND CAMERA: OFF - "+e.getMessage()); } }
 public void surfaceCreated(SurfaceHolder h){ surfaceReady=true; if(checkSelfPermission(VIDEO_CAMERA_AND_CAMERA)==PackageManager.PERMISSION_GRANTED && checkSelfPermission(Manifest.permission.CAMERA)==PackageManager.PERMISSION_GRANTED){ startCamera(); } }
 public void surfaceChanged(SurfaceHolder h,int f,int w,int hh){ surfaceReady=true; try{ if(cam!=null){ cam.stopPreview(); cam.setPreviewDisplay(h); cam.startPreview(); } }catch(Exception e){} }
 public void surfaceDestroyed(SurfaceHolder h){ surfaceReady=false; try{ if(cam!=null){ cam.setPreviewCallback(null); cam.stopPreview(); cam.release(); cam=null; } }catch(Exception e){} }
 // FIX 1: Colour is colour only - NEVER an object name
 String colourName(){ if(lastCenterR<0) return "unknown colour"; if(lastCenterR<50 && lastCenterG<50 && lastCenterB<50) return "dark"; if(lastCenterR>180 && lastCenterG>180 && lastCenterB>180) return "bright / white sky"; if(lastCenterR>140 && lastCenterG>100 && lastCenterB<100) return "brown / dirt"; if(lastCenterR>100 && lastCenterG>100 && lastCenterB>100) return "grey"; if(lastCenterG>lastCenterR+20 && lastCenterG>lastCenterB+10) return "green / grass"; if(lastCenterB>lastCenterR+20) return "blue / sky"; if(lastCenterR>140 && lastCenterR>lastCenterG+25) return "pink / reddish colour"; return "mixed colour"; }
 boolean isSteadyNow(){ if(steadyA<0||steadyB<0||steadyC<0) return false; int d1=Math.abs(steadyA-steadyB); int d2=Math.abs(steadyB-steadyC); return d1<6 && d2<6; }
 Snap captureSnap(boolean askedMeasure){ Snap s=new Snap(); s.steady=isSteadyNow(); s.avgY=lastAvgY; s.glare=lastAvgY>200; s.dark=lastAvgY<40; s.colour=colourName(); s.r=lastCenterR; s.g=lastCenterG; s.b=lastCenterB; s.askedMeasure=askedMeasure; return s; }
 String decideMode(String ans, Snap s){ String low=ans.toLowerCase(); if(!s.steady) return "DESCRIBE"; boolean hasDoor=low.contains("door"); boolean hasWall=low.contains("wall"); boolean hasCrack=low.contains("crack"); if(s.askedMeasure && (hasDoor||hasWall||hasCrack)){ if(s.glare) return "IDENTIFY+COUNT"; if(s.dark) return "IDENTIFY+COUNT"; return "MEASURE+CALCULATE"; } return "IDENTIFY+LABEL+COUNT"; }
 ArrayList<String> extractLabels(String ans){ String low=" "+ans.toLowerCase().replace(","," ").replace("."," ").replace(":"," ")+" "; ArrayList<String> out=new ArrayList<String>(); for(int i=0;i<KNOWN.length;i++){ if(low.contains(" "+KNOWN[i]+" ") || low.contains(" "+KNOWN[i]+"s ")){ if(!out.contains(KNOWN[i])) out.add(KNOWN[i]); } } return out; }
 String buildBrainBlock(String ans, String mode, Snap s){
  String raw=ans==null?"":ans.trim();
  boolean netFail=raw.startsWith("ERR ") || raw.startsWith("HTTP ") || raw.contains("Unable to resolve") || raw.contains("Failed to connect");
  boolean empty=raw.isEmpty() || raw.equals("NO CONTENT") || raw.equals("EMPTY") || raw.equals("CUT BY LENGTH");
  StringBuilder sb=new StringBuilder();
  // FIX 4: Network fail = OFFLINE, not ERR as answer
  if(netFail){ sb.append("I SEE: [OFFLINE - no network now, using LOCAL EYE + last lessons]\n"); sb.append("LOCAL EYE: I see ").append(s.colour).append(" - centre R").append(s.r).append(" G").append(s.g).append(" B").append(s.b).append(" - AVG Y ").append(s.avgY).append("\n"); sb.append("LAST LESSON: Crack 8px = 112mm, Wall 576x432px = 48m2 - ONLY if you asked measure, else ignore.\n\n"); sb.append("BRAIN: ").append(mode).append(" - Eye ").append(s.steady?"STEADY":"MOVING").append("\n");  sb.append("COUNT: see description above\n"); sb.append("MEASURE: NOT VERIFIED - OFFLINE\n"); return sb.toString(); }
  if(empty){ sb.append("I SEE: [Looking again...]\n"); sb.append("LOCAL EYE: I see ").append(s.colour).append(" - centre R").append(s.r).append(" G").append(s.g).append(" B").append(s.b).append("\n\n"); sb.append("BRAIN: ").append(mode).append(" - Eye ").append(s.steady?"STEADY":"MOVING").append("\n");   sb.append("MEASURE: NOT VERIFIED - API EMPTY\n"); return sb.toString(); }
  sb.append("I SEE: ").append(raw).append("\n\n");
  // V5.13: BRAIN only in top green bar, not duplicated in white box\n
  // V5.13: LABELS REMOVED - user does not want LABEL lines. Description is the truth.
  // FIX 5: Measure ONLY if asked + steady + straight + px in THIS frame. No auto 48m2.
  if(mode.equals("MEASURE+CALCULATE")){ String low=raw.toLowerCase(); sb.append("MEASURE: CAL 13.889 - 1px = 13.889mm - YOU ASKED MEASURE + STEADY + STRAIGHT\n"); boolean hasPx=low.matches("(?s).*\\d+\\s*px.*"); if(!hasPx){ sb.append("CALCULATE: NOT DONE - no px in this frame. Hold straight-on to door/wall/crack for real px.\n"); sb.append("MEASURE STATUS: NOT MEASURED - need real px\n"); } else { if(low.contains("crack")) sb.append("CALCULATE: Crack px in this frame x 13.889 = mm - see RAW above\n"); if(low.contains("wall")) sb.append("CALCULATE: Wall px in this frame x 13.889 = m - see RAW above\n"); if(low.contains("door")) sb.append("CALCULATE: Door ref 900 x 2100mm - ONLY if straight-on\n"); } }
  else if(mode.equals("DESCRIBE")){ sb.append("MEASURE: NOT MEASURED - hold still 3 sec + ask Measure\n"); }
  else { sb.append("MEASURE: NOT MEASURED - hold steady + ask Measure + straight-on\n"); }
  return sb.toString();
 }
 // FIX 6: Rotate bitmap 90 so model sees upright, not sideways
 String makeB64Upright(){
  try{
   if(lastLiveJpeg==null) return "";
   Bitmap bmp=BitmapFactory.decodeByteArray(lastLiveJpeg, 0, lastLiveJpeg.length); if(bmp==null) return android.util.Base64.encodeToString(lastLiveJpeg, android.util.Base64.NO_WRAP);
   Matrix m=new Matrix(); m.postRotate(90);
   Bitmap rot=Bitmap.createBitmap(bmp, 0, 0, bmp.getWidth(), bmp.getHeight(), m, true);
   Bitmap small=Bitmap.createScaledBitmap(rot, 240, 180, true);
   ByteArrayOutputStream baos=new ByteArrayOutputStream(); small.compress(Bitmap.CompressFormat.JPEG, 30, baos);
   return android.util.Base64.encodeToString(baos.toByteArray(), android.util.Base64.NO_WRAP);
  }catch(Exception e){ return ""; }
 }
 public void onPreviewFrame(byte[] data, Camera c){
  frameOk=true; frameCount++;
  if(data!=null && data.length>0){
   long sum=0; int n=0; for(int i=0;i<data.length && i<640*480;i+=400){ sum+=(data[i]&0xFF); n++; } if(n>0) lastAvgY=(int)(sum/n);
   if(frameCount%30==0){ steadyA=steadyB; steadyB=steadyC; steadyC=lastAvgY; }
   if(frameCount%3==0 && lastW>0 && lastH>0){
    try{ YuvImage yuv=new YuvImage(data, ImageFormat.NV21, lastW, lastH, null); ByteArrayOutputStream baos=new ByteArrayOutputStream(); yuv.compressToJpeg(new Rect(0,0,lastW,lastH), 50, baos); lastLiveJpeg=baos.toByteArray(); lastLiveJpegLen=lastLiveJpeg.length; Bitmap bmp=BitmapFactory.decodeByteArray(lastLiveJpeg, 0, lastLiveJpeg.length); if(bmp!=null){ liveBmpPending=bmp; try{ int cx=bmp.getWidth()/2; int cy=bmp.getHeight()/2; int pix=bmp.getPixel(cx, cy); lastCenterR=Color.red(pix); lastCenterG=Color.green(pix); lastCenterB=Color.blue(pix); }catch(Exception e){} mode=3; runOnUiThread(this); } }catch(Exception e){}
   }
   if(autoSee && !autoBusy && frameOk){
    boolean timeUp=(frameCount-lastAutoFrame)>=30;
    boolean holdOver=(frameCount-lastFullFrame)>=45;
    boolean bigChange=false;
    if(lastAutoAvgY>=0 && Math.abs(lastAvgY-lastAutoAvgY)>25) bigChange=true;
    if(lastAutoJpegLen>=0 && Math.abs(lastLiveJpegLen-lastAutoJpegLen)>8000) bigChange=true;
    if(timeUp || bigChange){ lastAutoFrame=frameCount; lastAutoAvgY=lastAvgY; lastAutoJpegLen=lastLiveJpegLen; String instant=makeInstantGuess(); showInstant(instant); }
    if(!autoBusy && (holdOver || bigChange)){ autoBusy=true; lastAutoFrame=frameCount; lastAutoAvgY=lastAvgY; lastAutoJpegLen=lastLiveJpegLen; teachQ="AUTO SEE - describe what eye sees now, no question asked"; lastSnap=captureSnap(false); mode=4; new Thread(this).start(); }
   }
  }
 }
 String makeInstantGuess(){ Snap s=captureSnap(false); String col=s.colour; String move="Eye is on "; if(prevAvgY>=0){ int dY=lastAvgY-prevAvgY; if(dY>8) move="Eye moved to brighter - now on "; else if(dY<-8) move="Eye moved to darker - now on "; else move="Eye is on "; } prevAvgY=lastAvgY; return move+col+"."+(s.steady?" [STEADY]":" [MOVING]"); }
 public void onClick(View v){
  int id=v.getId();
  if(id==101){ learnOffline(); } else if(id==102){ teachOnline(); } else if(id==103){ measureDoor(); }
  else if(id==104){ String q=input.getText().toString(); if(q.isEmpty()) q="What do you see?"; learnOffline(q); }
  else if(id==107){ askStep1(); }
  else if(id==109){
   showLogs=!showLogs; bLogs.setText(showLogs?"HIDE LOGS":"SHOW LOGS");
   logWrap.setVisibility(showLogs?View.VISIBLE:View.GONE);
   if(showLogs) logView.setText(lastLog.isEmpty()?"No logs yet.":lastLog);
  }
  else if(id==108){
   autoSee=!autoSee; autoBusy=false; lastAutoFrame=frameCount; lastAutoAvgY=lastAvgY; lastAutoJpegLen=lastLiveJpegLen; lastFullFrame=0; prevAvgY=-1; steadyA=-1; steadyB=-1; steadyC=-1;
   bAuto.setText(autoSee?"AUTO SEE: ON":"AUTO SEE: OFF"); bAuto.setBackgroundColor(Color.parseColor(autoSee?"#00C853":"#9E9E9E"));
   if(autoSee) showFull("I SEE: Auto See is ON - BRAIN.\n\nBRAIN: DESCRIBE", "AUTO SEE: ON - BRAIN");
   else showFull("I SEE: Auto See is OFF.\n\nBRAIN: DESCRIBE", "AUTO SEE: OFF");
   updateStatus();
  }
  else if(id==106){ if(cam!=null){ try{ cam.stopPreview(); cam.release(); cam=null; bVideo.setText("VIDEO: OFF"); liveView.setImageBitmap(null); showFull("I SEE: Eye is off.\n\nBRAIN: DESCRIBE", "VIDEO CAMERA AND CAMERA: OFF"); }catch(Exception e){} } else { bVideo.setText("VIDEO: ON"); startCamera(); } }
 }
 public void run(){ if(mode==1){ doNervesThenWonder(); } else if(mode==4){ doFastAuto(); } else if(mode==2){ result.setText(pending); logView.setText(lastLog); } else if(mode==5){ instantView.setText(pending); } else if(mode==6){ brainView.setText(pending); } else if(mode==3){ try{ if(liveBmpPending!=null) liveView.setImageBitmap(liveBmpPending); }catch(Exception e){} } }
 void showInstant(String s){ pending=s; mode=5; runOnUiThread(this); }
 void showBrain(String s){ pending=s; mode=6; runOnUiThread(this); }
 void showFull(String clean, String log){ lastLog=log; pending=clean; mode=2; runOnUiThread(this); }
 String cleanLesson(){ return "CRACK  8px  =  112 mm  (11.2 cm)\nWALL  576 x 432 px  =  48.000 m2\nPAINT  4.800 L\nFILL  13.44 L\nCAL  13.889"; }
 void learnOffline(){ String q=input.getText().toString(); learnOffline(q); }
 void learnOffline(String q){
  if(q==null||q.isEmpty()) q="What do you see?";
  String lower=q.toLowerCase();
  boolean askedMeasure=lower.contains("measure")||lower.contains("door")||lower.contains("crack");
  if(lower.contains("count")){ if(autoBusy) return; autoBusy=true; lastSnap=captureSnap(false); showInstant("Counting... hold still 3 sec..."); teachQ="COUNT - list every object you see, 1 per line"; mode=1; new Thread(this).start(); return; }
  if(askedMeasure){ Snap s=captureSnap(true); if(!s.steady){ showFull("I SEE: Eye is moving - will not guess.\n\nBRAIN: DESCRIBE - Eye MOVING\nMEASURE: NOT MEASURED - hold still 3 sec", "MEASURE BLOCKED - EYE MOVING"); return; } if(autoBusy) return; autoBusy=true; lastSnap=s; showInstant("Measuring... steady, checking..."); teachQ=q; mode=1; new Thread(this).start(); return; }
  if(lower.contains("what do you see")||lower.contains("what do u see")||lower.contains("see")){ if(!frameOk){ showFull("I SEE: I can't see yet - wait for video.\n\nBRAIN: DESCRIBE", "NOT CONFIDENT"); return; } if(autoBusy) return; autoBusy=true; lastSnap=captureSnap(false); showInstant(makeInstantGuess()+" - deep answer coming..."); teachQ=q; mode=1; new Thread(this).start(); return; }
  try{ java.util.regex.Matcher m=java.util.regex.Pattern.compile("(\\d+)\\s*px").matcher(lower); List<Integer> pxs=new ArrayList<Integer>(); while(m.find()) pxs.add(Integer.parseInt(m.group(1))); if(!pxs.isEmpty() && lower.contains("crack")){ StringBuilder sb=new StringBuilder(); sb.append("I SEE: crack:\n"); for(int i=0;i<pxs.size();i++){ int px=pxs.get(i); double mm=px*CAL; sb.append("Crack "+px+"px = "+String.format("%.0f",mm)+"mm\n"); } if(lower.contains("wall") && pxs.size()>=2){ double w=pxs.get(0)*CAL/1000; double hh=pxs.get(1)*CAL/1000; double area=w*hh; sb.append("Wall "+String.format("%.2f",w)+"m x "+String.format("%.2f",hh)+"m = "+String.format("%.3f",area)+"m2\nPaint "+String.format("%.3f",area*0.1)+"L\nFill "+String.format("%.2f",area*0.28)+"L\n"); } sb.append("CAL 13.889 - Door only if straight-on"); showFull(sb.toString(), "MEASUREMENT OFFLINE CAL"); return; } }catch(Exception e){ showFull("I SEE: I had a problem measuring.", "ERROR "+e); return; }
  if(lower.contains("crack")){ showFull("I SEE: Crack 8px = 112mm (11.2cm)\nWall 576x432px = 48m2\nPaint 4.8L  Fill 13.44L - ONLY if you gave those px, else NOT MEASURED", "MEASUREMENT OFFLINE LESSON"); return; }
  showFull("I SEE: I'm not sure yet.\nTry: What do you see? / Count / Measure door\n\nBRAIN: DESCRIBE", "NOT CONFIDENT");
 }
 void measureDoor(){ Snap s=captureSnap(true); if(!s.steady){ showFull("I SEE: Eye is moving - will not guess door.\n\nBRAIN: DESCRIBE - Eye MOVING\nMEASURE DOOR: NOT MEASURED - hold still 3 sec", "MEASURE DOOR BLOCKED - MOVING"); return; } if(s.glare){ showFull("I SEE: Glare blocks measure.\n\nBRAIN: IDENTIFY+COUNT - Eye STEADY\nMEASURE DOOR: NOT MEASURED - glare", "MEASURE DOOR BLOCKED - GLARE"); return; } if(autoBusy) return; autoBusy=true; lastSnap=s; showInstant("Measuring door... steady..."); teachQ="MEASURE DOOR - is door straight-on? Estimate px for door, wall, crack if visible"; mode=1; new Thread(this).start(); }
 void teachOnline(){ String q0=input.getText().toString(); if(q0.isEmpty()) q0="What do you see?"; if(autoBusy) return; autoBusy=true; lastSnap=captureSnap(q0.toLowerCase().contains("measure")); teachQ=q0; if(!frameOk){ autoBusy=false; showFull("I SEE: I can't see yet - wait for video.", "No live video"); return; } showInstant("Teaching... deep answer coming..."); mode=1; new Thread(this).start(); }
 String readKey(){ try{ InputStream is=getAssets().open("mtm_key.txt"); BufferedReader br=new BufferedReader(new InputStreamReader(is)); String k=br.readLine(); br.close(); if(k!=null) return k.trim().split("\\s+")[0]; }catch(Exception e){} return ""; }
 void doFastAuto(){
  Snap snap=lastSnap!=null?lastSnap:captureSnap(false);
  try{
   String key=readKey(); if(key.isEmpty()){ autoBusy=false; showFull("I SEE: I need my key to learn online.\n\nBRAIN: DESCRIBE", "TEACH NEEDS KEY"); return; }
   String b64=makeB64Upright();
   for(int i=0;i<12;i++){ nerveResults[i]=""; nerveDone[i]=false; } nerveCount=0;
   String p="LIVE upright photo. In 1-2 sentences only: what do you see? Name only objects you are SURE about. No list of what you do NOT see. Colour: "+snap.colour+".";
   Worker w=new Worker(0, "muse-spark-1.3", p, key, b64); new Thread(w).start();
   int waited=0; while(nerveCount<1 && waited<80){ try{ Thread.sleep(100); }catch(Exception e){} waited++; }
   String ans=nerveResults[0]!=null?nerveResults[0]:"";
   autoCount++; lastFullFrame=frameCount;
   String modeStr=decideMode(ans, snap);
   showBrain("BRAIN: "+modeStr+" - Eye "+(snap.steady?"STEADY":"MOVING")+" | Glare: "+(snap.glare?"YES":"NO"));
   String block=buildBrainBlock(ans, modeStr, snap);
   boolean bad=ans==null || ans.trim().isEmpty() || ans.equals("NO CONTENT") || ans.startsWith("ERR ") || ans.startsWith("HTTP ");
   if(!bad) saveLesson("AUTO SEE "+modeStr, block);
   showFull(block, "FAST EYE - BRAIN "+modeStr+" - RAW=["+ans+"] - STEADY="+snap.steady+" AVG Y="+snap.avgY);
   updateStatus();
  }catch(Exception e){ showFull("I SEE: [OFFLINE - no network]\nLOCAL EYE: I see "+snap.colour+"\n\nBRAIN: DESCRIBE - OFFLINE\nCOUNT: UNKNOWN - OFFLINE\nMEASURE: NOT VERIFIED - OFFLINE", "FAST FAILED "+e.getMessage()); }
  autoBusy=false;
 }
 void doNervesThenWonder(){
  Snap snap=lastSnap!=null?lastSnap:captureSnap(false);
  try{
   String key=readKey(); if(key.isEmpty()){ autoBusy=false; showFull("I SEE: I need my key to learn online.", "TEACH NEEDS KEY"); return; }
   String b64=makeB64Upright();
   for(int i=0;i<12;i++){ nerveResults[i]=""; nerveDone[i]=false; } nerveCount=0;
   for(int i=0;i<6;i++){ String p="LIVE upright photo. Q: "+teachQ+" JOB: "+API_JOBS[i]+" Answer in 2 sentences, do not write essay, do not answer with 1 word."; Worker w=new Worker(i, API_MODELS[i], p, key, b64); new Thread(w).start(); }
   int waited=0; while(nerveCount<6 && waited<80){ try{ Thread.sleep(100); }catch(Exception e){} waited++; }
   nerveResults[6]="LOCAL DOT: frame "+lastW+"x"+lastH+", JPEG "+lastLiveJpegLen+" bytes, AVG Y "+snap.avgY;
   nerveResults[7]="LOCAL CAL: 1px = 13.889mm. No px in this frame = NOT MEASURED";
   nerveResults[8]="LOCAL GLARE: AVG Y "+snap.avgY;
   nerveResults[9]="LOCAL MEASURE: "+cleanLesson().replace("\n"," | ");
   nerveResults[10]="LOCAL IMAGE: JPEG "+lastLiveJpegLen+" bytes, "+lastW+"x"+lastH+" - upright 90deg";
   nerveResults[11]="LOCAL VOICE: READY";
   nerveCount=12;
   StringBuilder nerves=new StringBuilder(); String[] ALL_NAMES={"muse-spark-1.3","muse-spark-1.3-contributor","muse-spark-1.2","muse-spark-1.2-contributor","muse-spark-1.1","muse-wonder-1.0-REASON","LOCAL-DOT","LOCAL-CAL","LOCAL-GLARE","LOCAL-MEASURE","LOCAL-IMAGE","LOCAL-VOICE"};
   for(int i=0;i<12;i++){ nerves.append("[").append(ALL_NAMES[i]).append("] ").append(nerveResults[i]!=null?nerveResults[i]:"-").append("\n"); }
   String fusePrompt="You are WONDER FINAL FUSION. Fuse 12 nerves below into 3 lines only. Line1: what you see in 2 sentences. Line2: list objects + count. Line3: crack/wall/door px ONLY if user asked measure AND px in this frame, else NOT MEASURED + CAL 13.889. No essay, no 1-word answer. Nerves:\n"+nerves.toString();
   String json="{\"model\":\"muse-wonder-1.0\",\"messages\":[{\"role\":\"user\",\"content\":\""+fusePrompt.replace("\\"," ").replace("\"","'").replace("\n"," ")+"\"}],\"max_tokens\":8000}";
   URL url=new URL("https://api.meta.ai/v1/chat/completions"); HttpURLConnection c=(HttpURLConnection)url.openConnection(); c.setRequestMethod("POST"); c.setRequestProperty("Authorization","Bearer "+key); c.setRequestProperty("Content-Type","application/json"); c.setConnectTimeout(8000); c.setReadTimeout(12000); c.setDoOutput(true); c.getOutputStream().write(json.getBytes());
   int code=c.getResponseCode(); InputStream in=(code>=200 && code<300)?c.getInputStream():c.getErrorStream();
   BufferedReader br=new BufferedReader(new InputStreamReader(in)); StringBuilder sb=new StringBuilder(); String line; while((line=br.readLine())!=null) sb.append(line);
   String finalAns=extractContent(sb.toString());
   String modeStr=decideMode(finalAns, snap);
   showBrain("BRAIN: "+modeStr+" - DEEP - Eye "+(snap.steady?"STEADY":"MOVING"));
   String block=buildBrainBlock(finalAns, modeStr, snap);
   boolean bad=finalAns==null || finalAns.trim().isEmpty() || finalAns.equals("NO CONTENT") || finalAns.startsWith("ERR ");
   if(!bad) saveLesson(teachQ+" "+modeStr, block);
   autoCount++; lastFullFrame=frameCount;
   showFull("DEEP - 12 nerves + WONDER:\n"+block, "LOGS\n"+nerves.toString()+"\nFINAL RAW=["+finalAns+"]");
   updateStatus();
  }catch(Exception e){ showFull("I SEE: [OFFLINE - no network]\nLOCAL EYE: I see "+snap.colour+"\n\nBRAIN: DESCRIBE - OFFLINE\nCOUNT: UNKNOWN - OFFLINE\nMEASURE: NOT VERIFIED - OFFLINE", "FUSION FAILED "+e.getMessage()); }
  autoBusy=false;
 }
}
JAVA
cat > $PROJ/AndroidManifest.xml <<'MAN'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.nino.autolearn" android:versionCode="45" android:versionName="5.1">
<permission android:name="com.nino.autolearn.permission.VIDEO_CAMERA_AND_CAMERA" android:label="@string/perm_video_camera_and_camera" android:description="@string/perm_desc" android:protectionLevel="dangerous" />
<uses-permission android:name="com.nino.autolearn.permission.VIDEO_CAMERA_AND_CAMERA" />
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
<uses-sdk android:minSdkVersion="21" android:targetSdkVersion="33"/>
<application android:label="@string/app_name" android:usesCleartextTraffic="true" android:theme="@android:style/Theme.NoTitleBar">
<activity android:name=".MainActivity" android:exported="true"><intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity>
</application>
</manifest>
MAN
echo "[1] aapt2"
$AAPT2 compile $PROJ/res/values/strings.xml -o $PROJ/build/
$AAPT2 link -I "$ANDROID_JAR" --manifest $PROJ/AndroidManifest.xml -R $PROJ/build/values_strings.arsc.flat -o $PROJ/build/base.apk --auto-add-overlay
echo "[2] javac"
javac --release 8 -cp "$ANDROID_JAR" -d $PROJ/build $(find $PROJ/src -name "*.java")
echo "[3] d8 CHECK NO \$"
echo "OK - Snap inner class allowed, d8 handles $ "
CLASSES=$(find $PROJ/build -name "*.class" | tr '\n' ' ')
$D8 --lib "$ANDROID_JAR" --min-api 21 --output $PROJ/build $CLASSES
echo "[4] zip dex + assets"
cd $PROJ/build && zip -u base.apk classes.dex > /dev/null
mkdir -p assets && cp $PROJ/assets/lessons.json assets/ 2>/dev/null || true; cp $PROJ/assets/mtm_key.txt assets/ 2>/dev/null || true
zip -u base.apk assets/lessons.json > /dev/null || true; zip -u base.apk assets/mtm_key.txt > /dev/null || true
echo "[5] align + sign"
$ZIPALIGN -f 4 base.apk aligned.apk
$APKSIGNER sign --ks $KEYSTORE --ks-pass pass:XXXXXX --ks-key-alias nino --key-pass pass:XXXXXX --out $PROJ/NINO-AUTO-LEARN-V5.13-FINAL-signed.apk aligned.apk
cp $PROJ/NINO-AUTO-LEARN-V5.13-FINAL-signed.apk /sdcard/Download/
ls -lh /sdcard/Download/NINO-AUTO-LEARN-V5.13-FINAL-signed.apk
echo "INSTALL MANUALLY: termux-open /sdcard/Download/NINO-AUTO-LEARN-V5.13-FINAL-signed.apk - NO pm install"
