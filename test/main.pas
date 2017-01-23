unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, LazSerial,
  StdCtrls, ExtCtrls, ComCtrls,inifiles,Math, lazsynaser;

type

  { TFMain }

  TFMain = class(TForm)
    BStartSimu: TButton;
    BOpen: TButton;
    BClose: TButton;
    BPortSettings: TButton;
    BClearMemo: TButton;
    CB_GGA: TCheckBox;
    CB_RMC: TCheckBox;
    EditAlt: TEdit;
    EditCourse: TEdit;
    EditDegLat: TEdit;
    EditDegLon: TEdit;
    EditDevice: TEdit;
    EditMinLat: TEdit;
    EditMinLon: TEdit;
    EditPoleLat: TEdit;
    EditPoleLon: TEdit;
    EditSpeed: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Memo: TMemo;
    Serial: TLazSerial;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    procedure BClearMemoClick(Sender: TObject);
    procedure BCloseClick(Sender: TObject);
    procedure BOpenClick(Sender: TObject);
    procedure BStartSimuClick(Sender: TObject);
    procedure BPortSettingsClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure SerialRxData(Sender: TObject);
    procedure SerialStatus(Sender: TObject; Reason: THookSerialReason;
      const Value: string);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

type
    NMEAstr=record
    time:string[10];
    date:string[10];
    latitude:string[10];
    longitude:string[10];
    speed:string[10];
    rec:string[10];
    altitude:string[10];
    end;

var
  FMain: TFMain;
  IniFile: TiniFile;
  Longitude,Latitude: Extended;
  PoleLat,PoleLon,ChaineLatitude,ChaineLongitude: String;
  FlipFlopEnvoi : Boolean=True;
  CurPos : integer;
  FTempStr: String;
  HeureGPS: Boolean;
  SimuEnRoute: Boolean;
  CapFich: String;
  DistanceFich: Integer;
  DistanceCourante :  Double;
  IncDistance : Double;
  IncFich: Integer;
  VitesseFich : String;
  RowCur : Integer;
  CapCourant : Integer;

implementation
{$R *.lfm}

function nextcomma(s:string;var index:byte; var sub:string):boolean;
var j:byte;
begin
j:=index;sub:='';
while(s[j]<>',')and(s[j]<>'*')do begin
sub:=sub+s[j];inc(j);
end;
nextcomma:=(index=j);
index:=j+1;
end;

procedure AnalyseTrames(var s: string);
var NMEAStrings : NMEAstr;
var index: byte;
var sub:string = '';
var posGGA : integer;
begin
NMEAStrings.time := '';
posGGA :=  pos('$GPGGA', s);
if (posGGA > 0) and (not SimuEnRoute) then
    begin
      index := posGGA + 7;
      if not nextcomma(s,index,sub)then
          // time
         begin
           NMEAStrings.time := sub;
         end;
         if not nextcomma(s,index,sub) then
          // Latitude
          begin
          FMain.EditDegLat.Text := Copy(sub,1,2);
          FMain.EditMinLat.Text := Copy(sub,3,6);
          end;
         if not nextcomma(s,index,sub) then
          // Nord Sud indicateur
          begin
          FMain.EditPoleLat.Text := Copy(sub,1,1);
          end;
          if not nextcomma(s,index,sub) then
          // Longitude
          begin
          FMain.EditDegLon.Text := Copy(sub,1,3);
          FMain.EditMinLon.Text := Copy(sub,4,6);
          end;
          if not nextcomma(s,index,sub) then
          // Est Ouest Indicateur
          begin
          FMain.EditPoleLon.Text := Copy(sub,1,1);
          end;
          if not nextcomma(s,index,sub) then
          // Position Fixe
          begin

          end;
          if not nextcomma(s,index,sub) then
          // Satellites utilisés
          begin

          end;
          if not nextcomma(s,index,sub) then
          // HDOP
          begin

          end;
          if not nextcomma(s,index,sub) then
          // Altitude
          begin
          FMain.EditAlt.Text := copy(sub,1,5);
          end;
          if not nextcomma(s,index,sub) then
          // Unité Altitude
          begin

          end;
         end;

    end;

{ TFMain }


procedure TFMain.FormActivate(Sender: TObject);
begin
CapFich := '0';
IncFich := 0;
DistanceFich := 0;
VitesseFich := '0';
end;

procedure TFMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if Serial.Active then
    Serial.Active := false ;
  IniFile.WriteString('Coord', 'DegLon', EditDegLon.Text);
  IniFile.WriteString('Coord', 'MinLon', EditMinLon.Text);
  IniFile.WriteString('Coord', 'PoleLon',EditPoleLon.Text);
  IniFile.WriteString('Coord', 'DegLat', EditDegLat.Text);
  IniFile.WriteString('Coord', 'MinLat', EditMinLat.Text);
  IniFile.WriteString('Coord', 'PoleLat',EditPoleLat.Text);
  IniFile.WriteString('Other', 'Altitude',EditAlt.Text);
  IniFile.WriteString('Other', 'Speed',EditSpeed.Text);
  IniFile.WriteString('Other', 'Heading',EditCourse.Text);
  IniFile.Free;
  Application.Terminate;
end;




function checksum(Chaine: String) : Byte;    // calcul checksum
var x: integer;
var checkcalc: Byte;
begin
        x:=1;
        checkcalc:= 0;
        while  Chaine[x] <> '*' do
           begin
             if Chaine[x] <> '$'  then   checkcalc := ord(chaine[x])XOR checkcalc ;
             x:= x +1 ;
           end;
     checksum := checkcalc;
end;

{ TFMain }



procedure TFMain.FormCreate(Sender: TObject);
begin
{$IFDEF LINUX}
 IniFile := TIniFile.Create(
 GetAppConfigFile(False) + '.conf');

{$ELSE}
 IniFile := TIniFile.Create(
 ExtractFilePath(Application.EXEName) + 'SimuGps.ini');
{$ENDIF}
 EditDegLon.Text := IniFile.ReadString('Coord', 'DegLon', '002');
 EditMinLon.Text := IniFile.ReadString('Coord', 'MinLon', '20.977');
 EditPoleLon.Text := IniFile.ReadString('Coord', 'PoleLon', 'E');
 EditDegLat.Text := IniFile.ReadString('Coord', 'DegLat', '48');
 EditMinLat.Text := IniFile.ReadString('Coord', 'MinLat', '51.184');
 EditPoleLat.Text := IniFile.ReadString('Coord', 'PoleLat', 'N');
 EditAlt.Text := IniFile.ReadString('Other', 'Altitude', '035');
 EditSpeed.Text := IniFile.ReadString('Other', 'Speed', '000');
 EditCourse.Text := IniFile.ReadString('Other', 'Heading', '000');
 EditDevice.Text := Serial.Device;
 Memo.DoubleBuffered := true;
end;


procedure TFMain.BStartSimuClick(Sender: TObject);
var
  Str: String;
  dd : Extended;

begin
   DecimalSeparator:='.';
  if FlipFlopEnvoi = False then
  begin
   FlipFlopEnvoi := True;
   BStartSimu.Caption := 'Start Simulator';
   SimuEnRoute := False;
   Timer1.Enabled := False;
  end
  else
  begin
  FlipFlopEnvoi := False;
  BStartSimu.Caption := 'Stop Simulator';
  SimuEnRoute := True;
  PoleLat := EditPoleLat.Text;
  PoleLon := EditPoleLon.Text;
  dd := StrToFloat(EditMinLat.Text)/60;
  if PoleLat = 'N' then
  Latitude := StrToFloat(EditDegLat.Text)+ dd
  else
  Latitude := -StrToFloat(EditDegLat.Text) - dd;
  dd := StrToFloat(EditMinLon.Text)/60;
  if PoleLon = 'E' then
  Longitude := StrToFloat(EditDegLon.Text)+ dd
  else
  Longitude := -StrToFloat(EditDegLon.Text) - dd;
  ChaineLatitude  :=  FormatFloat('0000.000',Trunc(Abs(Latitude))*100 +
                      (Abs(Latitude) -  Trunc(Abs(Latitude)))*60);
  ChaineLongitude := FormatFloat('00000.000',Trunc(Abs(Longitude))*100 +
                      (Abs(Longitude) -  Trunc(Abs(Longitude)))*60);
  if CB_GGA.Checked then
  begin
  Str := '$GPGGA,' +
       FormatDateTime('hhnnss".00,"',now ) +
       ChaineLatitude +
       ',' + PoleLat + ',' +
       ChaineLongitude +
       ',' + PoleLon + ',' +
       '1,04,47.56,' + EditAlt.Text + ',M,10,M,,*';
  Str := Str + inttohex(checksum(Str),2)+ Char(13)+ Char(10);
  Serial.WriteData(Str);
  Str := '$GPGLL,' +
       ChaineLatitude +
       ',' + PoleLat + ',' +
       ChaineLongitude +
       ',' + PoleLon + ',' +
       FormatDateTime('hhnnss".00,"',now ) +
       'A*';
  Str := Str + inttohex(checksum(Str),2)+ Char(13)+ Char(10);;
  Serial.WriteData(Str);
  end;
  if CB_RMC.Checked then
  begin
  Str := '$GPRMC,' +
         FormatDateTime('hhnnss","',now ) +
         'A,' +
         ChaineLatitude +
         ',' + PoleLat + ',' +
         ChaineLongitude +
         ',' + PoleLon + ',' +
         '000.5,054.7,' +
         FormatDateTime('ddmmyy","',now ) +
         '020.3,E*';
   Str := Str +  inttohex(checksum(Str),2)+ Char(13)+ Char(10);
   Serial.WriteData(Str);
  end ;
  Timer1.Enabled := True;
  end;
end;

procedure TFMain.BPortSettingsClick(Sender: TObject);
begin
  Serial.ShowSetupDialog;
  EditDevice.Text := Serial.Device;
end;



procedure TFMain.BOpenClick(Sender: TObject);
begin
  Serial.Device := EditDevice.Text;
  Serial.Open;
end;

procedure TFMain.BCloseClick(Sender: TObject);
begin
  Serial.Close;
end;

procedure TFMain.BClearMemoClick(Sender: TObject);
begin
  Memo.Clear;
end;

procedure TFMain.SerialRxData(Sender: TObject);
var Str : string;
begin
  Str :=  Serial.ReadData;
  CurPos := Pos( Char(10) ,Str);
  if CurPos = 0 then begin
    FTempStr := FTempStr + Str;
  end
  else begin
    FTempStr := FTempStr + Copy( Str, 1, CurPos-1);
    Memo.Lines.BeginUpdate;
    Memo.Lines.Add(FtempStr);
     Memo.Lines.EndUpdate;
    Memo.SelStart := Length(Memo.Lines.Text)-1;
    Memo.SelLength:=0;
    AnalyseTrames(FtempStr);
    FTempStr := Copy(Str,CurPos +1, Length(Str) - CurPos);
  end;

end;

procedure TFMain.SerialStatus(Sender: TObject; Reason: THookSerialReason;
  const Value: string);
begin
  case Reason of
    HR_SerialClose : StatusBar1.SimpleText := 'Port ' + Value + ' closed';
    HR_Connect :   StatusBar1.SimpleText := 'Port ' + Value + ' connected';
//    HR_CanRead :   StatusBar1.SimpleText := 'CanRead : ' + Value ;
//    HR_CanWrite :  StatusBar1.SimpleText := 'CanWrite : ' + Value ;
//    HR_ReadCount : StatusBar1.SimpleText := 'ReadCount : ' + Value ;
//    HR_WriteCount : StatusBar1.SimpleText := 'WriteCount : ' + Value ;
    HR_Wait :  StatusBar1.SimpleText := 'Wait : ' + Value ;

  end ;

end;

procedure TFMain.Timer1Timer(Sender: TObject);
var
  Str: String;
  cap,increment : Extended;
const
  //CoeffInc = (interval_timer)/( km/h -> m/s)*(coeff Nautic Miles)*( ' -> °)
  CoeffInc  = (2*1)/(3600*1.852*60);
begin
DistanceCourante := DistanceCourante + IncDistance;
CapCourant := StrToInt(EditCourse.Text);
if DistanceCourante > DistanceFich then
     begin
      RowCur := RowCur + 1 ;
      DistanceCourante := 0;
      if IncFich <> 0 then
         begin
         if CapCourant > 359 then CapCourant := 0;
         if CapCourant < 0 then CapCourant := 359;
         CapCourant := CapCourant + IncFich;
         EditCourse.Text := IntTostr(CapCourant);
         end;
     end;
cap := DegToRad(CapCourant);
increment := StrToFloat(EditSpeed.Text)*(CoeffInc);
Latitude := Latitude +  increment*cos(cap);
if Latitude > 0 then
   PoleLat := 'N'
   else
   PoleLat := 'S';
Longitude := Longitude + increment*sin(cap)/cos(DegToRad(Latitude));
if Longitude > 0 then
   PoleLon := 'E'
   else
   PoleLon := 'W';
ChaineLatitude  := FormatFloat('0000.000',Trunc(Abs(Latitude))*100 +
                   (Abs(Latitude) -  Trunc(Abs(Latitude)))*60);
ChaineLongitude := FormatFloat('00000.000',Trunc(Abs(Longitude))*100 +
                   (Abs(Longitude) -  Trunc(Abs(Longitude)))*60);
if CB_GGA.Checked then
begin
Str := '$GPGGA,' +
       FormatDateTime('hhnnss".00,"',now ) +
       ChaineLatitude +
       ',' + PoleLat + ',' +
       ChaineLongitude +
       ',' + PoleLon + ',' +
       '1,04,47.56,' + EditAlt.Text + ',M,10,M,,*';
  Str := Str + inttohex(checksum(Str),2)+ Char(13)+ Char(10);
  Serial.WriteData(Str);
  Str := '$GPGLL,' +
       ChaineLatitude +
       ',' + PoleLat + ',' +
       ChaineLongitude +
       ',' + PoleLon + ',' +
       FormatDateTime('hhnnss".00,"',now ) +
       'A*';
  Str := Str + inttohex(checksum(Str),2)+ Char(13)+ Char(10);;
  Serial.WriteData(Str);
end ;
if CB_RMC.Checked then
  begin
  Str := '$GPRMC,' +
         FormatDateTime('hhnnss","',now ) +
         'A,' +
         ChaineLatitude +
         ',' + PoleLat + ',' +
         ChaineLongitude +
         ',' + PoleLon + ',' +
         '000.5,054.7,' +
         FormatDateTime('ddmmyy","',now ) +
         '020.3,E*';
   Str := Str +  inttohex(checksum(Str),2)+ Char(13)+ Char(10);
   Serial.WriteData(Str);
  end  ;

  EditDegLat.Text := Copy(ChaineLatitude,1,2);
  EditMinLat.text := Copy(ChaineLatitude,3,6);
  EditDegLon.Text := Copy(ChaineLongitude,1,3);
  EditMinLon.text := Copy(ChaineLongitude,4,6);
  EditPoleLat.Text := PoleLat;
  EditPoleLon.Text := PoleLon;
end;



end.

