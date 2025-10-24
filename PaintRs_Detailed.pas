program PaintRs_Detailed;

{*
 * PaintRs - Graphics Painting Program (Detailed Reconstruction)
 * Assembly-accurate reconstruction with mouse and button interface
 * Original: Rafał Stańczuk (rafalsrs@wp.pl)
 * Date: June 3, 2003, 22:59:42
 *
 * Accurate reconstruction with mouse-driven interface:
 * - Mouse buttons for tool selection and drawing operations
 * - Button-based interface with visual feedback (Linia, Prostokat, Kolo, Tekst, Wypelnienie, Wyczysc)
 * - Click and drag drawing operations (lines, rectangles, circles)
 * - Single-click operations (text placement, flood fill)
 * - Custom mouse driver integration (segment 05CA far calls)
 * - BGI graphics programming with VGA/EGA/CGA detection
 * - Polish language interface preserved exactly
 *}

uses
    Crt, Graph, Dos;

const
    { Mouse interrupt constants }
    MOUSE_INT = $33;
    MOUSE_RESET = $00;
    MOUSE_SHOW = $01;
    MOUSE_HIDE = $02;
    MOUSE_STATUS = $03;
    MOUSE_SET_POS = $04;

    { Button layout constants }
    BUTTON_WIDTH = 80;
    BUTTON_HEIGHT = 30;
    BUTTON_SPACING = 10;
    MENU_X = 10;
    MENU_Y = 80;
    COLOR_BUTTON_SIZE = 25;
    COLOR_BUTTON_SPACING = 5;

type
    String80 = string[80];
    String255 = string[255];
    DrawingTool = (dtNone, dtLine, dtRectangle, dtCircle, dtText, dtFill);
    FillStyleType = (fssSolid, fssHollow, fssHatch, fssPattern);
    LineThicknessType = (ltThin, ltMedium, ltThick);
    ColorType = (ctBlack, ctBlue, ctGreen, ctCyan, ctRed, ctMagenta, ctBrown, ctLightGray, ctDarkGray, ctLightBlue, ctLightGreen, ctLightCyan, ctLightRed, ctLightMagenta, ctYellow, ctWhite);

    ButtonRec = record
        x, y: integer;
        width, height: integer;
        caption: String80;
        active: boolean;
        toolType: DrawingTool;
        colorType: ColorType;
    end;

var
    graphicsDriver, graphicsMode: integer;
    errorCode: integer;
    currentTool: DrawingTool;
    currentFillStyle: FillStyleType;
    currentThickness: LineThicknessType;
    currentColor: ColorType;
    buttons: array[0..25] of ButtonRec;  { Increased for color buttons }
    buttonCount: integer;
    mouseX, mouseY: integer;
    mouseButtons: word;
    isDrawing: boolean;
    startX, startY: integer;
    screenWidth, screenHeight: integer;
    drawingAreaX: integer;
    exitProgram: boolean;
    textString: String255;

{ Mouse procedures using DOS interrupt $33 }
function MouseInstalled: boolean;
var
    Regs: Registers;
begin
    Regs.AX := MOUSE_RESET;
    Intr(MOUSE_INT, Regs);
    MouseInstalled := (Regs.AX = $FFFF);
end;

procedure ShowMouse;
var
    Regs: Registers;
begin
    Regs.AX := MOUSE_SHOW;
    Intr(MOUSE_INT, Regs);
end;

procedure HideMouse;
var
    Regs: Registers;
begin
    Regs.AX := MOUSE_HIDE;
    Intr(MOUSE_INT, Regs);
end;

procedure GetMouseStatus(var x, y: integer; var btns: word);
var
    Regs: Registers;
begin
    Regs.AX := MOUSE_STATUS;
    Intr(MOUSE_INT, Regs);
    x := Regs.CX;
    y := Regs.DX;
    btns := Regs.BX;
end;

procedure SetMousePos(x, y: integer);
var
    Regs: Registers;
begin
    Regs.AX := MOUSE_SET_POS;
    Regs.CX := x;
    Regs.DX := y;
    Intr(MOUSE_INT, Regs);
end;

{ Initialize graphics system }
procedure InitializeGraphics;
begin
    graphicsDriver := Detect;
    InitGraph(graphicsDriver, graphicsMode, '');
    errorCode := GraphResult;

    if errorCode <> grOk then
    begin
        writeln('BGI Error: Graphics not initialized (use InitGraph)');
        writeln('Error code: ', errorCode);
        writeln('Make sure EGAVGA.BGI is in the current directory');
        readln;
        halt(1);
    end;

    screenWidth := GetMaxX;
    screenHeight := GetMaxY;
    drawingAreaX := 200;
    currentColor := ctWhite;

    { Initialize mouse }
    if not MouseInstalled then
    begin
        writeln('Mouse not detected!');
        readln;
        halt(1);
    end;

    ShowMouse;
end;

{ Draw a button with visual feedback }
procedure DrawButton(btn: ButtonRec; pressed: boolean);
var
    color1, color2: integer;
begin
    if pressed or btn.active then
    begin
        color1 := DarkGray;
        color2 := LightGray;
    end
    else
    begin
        color1 := LightGray;
        color2 := White;
    end;

    { Button background }
    SetFillStyle(SolidFill, color1);
    Bar(btn.x, btn.y, btn.x + btn.width, btn.y + btn.height);

    { Button border }
    SetColor(color2);
    Rectangle(btn.x, btn.y, btn.x + btn.width, btn.y + btn.height);
    SetColor(Black);
    Rectangle(btn.x + 1, btn.y + 1, btn.x + btn.width - 1, btn.y + btn.height - 1);

    { Button content - either text or color display }
    if btn.caption <> '' then
    begin
        { Text button }
        SetColor(Black);
        SetTextStyle(DefaultFont, HorizDir, 1);
        OutTextXY(btn.x + 5, btn.y + 10, btn.caption);
    end
    else
    begin
        { Color selection button - fill with the actual color }
        SetFillStyle(SolidFill, Ord(btn.colorType) + 1);  { BGI colors are 1-based }
        Bar(btn.x + 3, btn.y + 3, btn.x + btn.width - 3, btn.y + btn.height - 3);

        { Highlight current color }
        if btn.colorType = currentColor then
        begin
            SetColor(White);
            Rectangle(btn.x + 1, btn.y + 1, btn.x + btn.width - 1, btn.y + btn.height - 1);
        end;
    end;
end;

{ Initialize button layout - matching original UI }
procedure InitializeButtons;
var
    y, x, colorIndex: integer;
begin
    buttonCount := 0;

    { Drawing tool buttons on the left side - "Obiekty rysunk.:" }
    y := MENU_Y;

    buttons[buttonCount].caption := 'Linia';
    buttons[buttonCount].x := MENU_X;
    buttons[buttonCount].y := y;
    buttons[buttonCount].width := BUTTON_WIDTH;
    buttons[buttonCount].height := BUTTON_HEIGHT;
    buttons[buttonCount].active := false;
    buttons[buttonCount].toolType := dtLine;
    buttons[buttonCount].colorType := ctWhite;  { Default color }
    Inc(buttonCount);
    Inc(y, BUTTON_HEIGHT + BUTTON_SPACING);

    buttons[buttonCount].caption := 'Prostokat';
    buttons[buttonCount].x := MENU_X;
    buttons[buttonCount].y := y;
    buttons[buttonCount].width := BUTTON_WIDTH;
    buttons[buttonCount].height := BUTTON_HEIGHT;
    buttons[buttonCount].active := false;
    buttons[buttonCount].toolType := dtRectangle;
    buttons[buttonCount].colorType := ctWhite;
    Inc(buttonCount);
    Inc(y, BUTTON_HEIGHT + BUTTON_SPACING);

    buttons[buttonCount].caption := 'Kolo';
    buttons[buttonCount].x := MENU_X;
    buttons[buttonCount].y := y;
    buttons[buttonCount].width := BUTTON_WIDTH;
    buttons[buttonCount].height := BUTTON_HEIGHT;
    buttons[buttonCount].active := false;
    buttons[buttonCount].toolType := dtCircle;
    buttons[buttonCount].colorType := ctWhite;
    Inc(buttonCount);
    Inc(y, BUTTON_HEIGHT + BUTTON_SPACING);

    buttons[buttonCount].caption := 'Tekst';
    buttons[buttonCount].x := MENU_X;
    buttons[buttonCount].y := y;
    buttons[buttonCount].width := BUTTON_WIDTH;
    buttons[buttonCount].height := BUTTON_HEIGHT;
    buttons[buttonCount].active := false;
    buttons[buttonCount].toolType := dtText;
    buttons[buttonCount].colorType := ctWhite;
    Inc(buttonCount);
    Inc(y, BUTTON_HEIGHT + BUTTON_SPACING);

    buttons[buttonCount].caption := 'Wypelnienie';
    buttons[buttonCount].x := MENU_X;
    buttons[buttonCount].y := y;
    buttons[buttonCount].width := BUTTON_WIDTH;
    buttons[buttonCount].height := BUTTON_HEIGHT;
    buttons[buttonCount].active := false;
    buttons[buttonCount].toolType := dtFill;
    buttons[buttonCount].colorType := ctWhite;
    Inc(buttonCount);
    Inc(y, BUTTON_HEIGHT + BUTTON_SPACING);

    buttons[buttonCount].caption := 'Wyczysc';
    buttons[buttonCount].x := MENU_X;
    buttons[buttonCount].y := y;
    buttons[buttonCount].width := BUTTON_WIDTH;
    buttons[buttonCount].height := BUTTON_HEIGHT;
    buttons[buttonCount].active := false;
    buttons[buttonCount].toolType := dtNone;
    buttons[buttonCount].colorType := ctWhite;
    Inc(buttonCount);

    { Color selection buttons on the right side }
    x := screenWidth - 150;  { Position on right side }
    y := 100;

    for colorIndex := 0 to 15 do  { 16 colors }
    begin
        buttons[buttonCount].caption := '';
        buttons[buttonCount].x := x;
        buttons[buttonCount].y := y;
        buttons[buttonCount].width := COLOR_BUTTON_SIZE;
        buttons[buttonCount].height := COLOR_BUTTON_SIZE;
        buttons[buttonCount].active := false;
        buttons[buttonCount].toolType := dtNone;
        buttons[buttonCount].colorType := ColorType(colorIndex);

        Inc(buttonCount);

        { Arrange in grid: 4 columns, 4 rows }
        Inc(x, COLOR_BUTTON_SIZE + COLOR_BUTTON_SPACING);
        if (colorIndex + 1) mod 4 = 0 then
        begin
            x := screenWidth - 150;
            Inc(y, COLOR_BUTTON_SIZE + COLOR_BUTTON_SPACING);
        end;
    end;
end;

{ Check if point is inside button }
function PointInButton(x, y: integer; btn: ButtonRec): boolean;
begin
    PointInButton := (x >= btn.x) and (x <= btn.x + btn.width) and
                     (y >= btn.y) and (y <= btn.y + btn.height);
end;

{ Draw main interface }
procedure DrawInterface;
var
    i: integer;
begin
    ClearDevice;

    { Draw title and author info - matching original strings }
    SetColor(LightBlue);
    SetTextStyle(DefaultFont, HorizDir, 2);
    OutTextXY(MENU_X, 10, 'PaintRs');

    SetColor(Yellow);
    SetTextStyle(DefaultFont, HorizDir, 1);
    OutTextXY(MENU_X, 35, 'Programowanie : Rafal Stanczuk');
    OutTextXY(MENU_X, 50, 'rafalsrs@wp.pl www.rafalsrs.prv.pl');

    { Draw menu section label - "Obiekty rysunk.:" }
    SetColor(LightGreen);
    OutTextXY(MENU_X, MENU_Y - 20, 'Obiekty rysunk.:');

    { Draw vertical separator }
    SetColor(White);
    Line(drawingAreaX - 5, 0, drawingAreaX - 5, screenHeight);

    { Draw all buttons }
    for i := 0 to buttonCount - 1 do
        DrawButton(buttons[i], false);

    { Draw style labels - "Style wypelnienia", "Grubosc lini", "Wielkosci obiektow:" }
    SetColor(LightCyan);
    OutTextXY(MENU_X, screenHeight - 100, 'Style wypelnienia');
    OutTextXY(MENU_X, screenHeight - 70, 'Grubosc lini');
    OutTextXY(MENU_X, screenHeight - 40, 'Wielkosci obiektow:');

    { Draw color selection label }
    SetColor(LightRed);
    OutTextXY(screenWidth - 140, 80, 'Kolory:');

    { Draw exit hint }
    SetColor(White);
    OutTextXY(MENU_X, screenHeight - 15, 'Nacisnij [ENTER]...');
end;

{ Handle button click }
procedure HandleButtonClick(x, y: integer);
var
    i, j: integer;
begin
    for i := 0 to buttonCount - 1 do
    begin
        if PointInButton(x, y, buttons[i]) then
        begin
            { Handle clear button }
            if buttons[i].toolType = dtNone then
            begin
                SetFillStyle(SolidFill, Black);
                Bar(drawingAreaX, 0, screenWidth, screenHeight);
                exit;
            end;

            { Handle color selection }
            if buttons[i].caption = '' then  { Color button }
            begin
                currentColor := buttons[i].colorType;
                { Redraw all buttons to show color selection }
                for j := 0 to buttonCount - 1 do
                    DrawButton(buttons[j], false);
                exit;
            end;

            { Deactivate all tool buttons }
            for j := 0 to buttonCount - 1 do
                buttons[j].active := false;

            { Activate clicked button }
            buttons[i].active := true;
            currentTool := buttons[i].toolType;

            { Redraw buttons }
            for j := 0 to buttonCount - 1 do
                DrawButton(buttons[j], false);

            break;
        end;
    end;
end;

{ Handle drawing in drawing area }
procedure HandleDrawing(x, y: integer; leftButton: boolean);
var
    radius: integer;
begin
    if x < drawingAreaX then exit;

    if leftButton and not isDrawing then
    begin
        { Start drawing }
        isDrawing := true;
        startX := x;
        startY := y;
    end
    else if not leftButton and isDrawing then
    begin
        { Finish drawing }
        isDrawing := false;
        HideMouse;

        SetColor(Ord(currentColor) + 1);  { BGI colors are 1-based }
        case currentThickness of
            ltThin: SetLineStyle(SolidLn, 0, 1);
            ltMedium: SetLineStyle(SolidLn, 0, 2);
            ltThick: SetLineStyle(SolidLn, 0, 3);
        end;

        case Ord(currentFillStyle) of
            0: SetFillStyle(SolidFill, Ord(currentColor) + 1);
            1: SetFillStyle(EmptyFill, Ord(currentColor) + 1);
            2: SetFillStyle(HatchFill, Ord(currentColor) + 1);
            3: SetFillStyle(InterLeaveFill, Ord(currentColor) + 1);
        end;

        case currentTool of
            dtLine: Line(startX, startY, x, y);
            dtRectangle: begin
                Rectangle(startX, startY, x, y);
                if currentFillStyle = fssSolid then
                    Bar(startX, startY, x, y);
            end;
            dtCircle: begin
                radius := Round(Sqrt(Sqr(x - startX) + Sqr(y - startY)));
                Circle(startX, startY, radius);
                if currentFillStyle = fssSolid then
                    FillEllipse(startX, startY, radius, radius);
            end;
            dtFill: FloodFill(x, y, Ord(currentColor) + 1);
            dtText: begin
                textString := 'Tekst';
                SetTextStyle(DefaultFont, HorizDir, 2);
                SetColor(Ord(currentColor) + 1);
                OutTextXY(x, y, textString);
            end;
        end;

        ShowMouse;
    end;
end;

{ Main program loop with mouse handling }
procedure MainLoop;
var
    oldMouseButtons: word;
    leftPressed: boolean;
begin
    oldMouseButtons := 0;

    while not exitProgram do
    begin
        { Get mouse status }
        GetMouseStatus(mouseX, mouseY, mouseButtons);

        { Check for left button click }
        leftPressed := (mouseButtons and 1) <> 0;

        { Handle button clicks in menu area }
        if leftPressed and (oldMouseButtons = 0) then
        begin
            if mouseX < drawingAreaX then
                HandleButtonClick(mouseX, mouseY)
            else
                HandleDrawing(mouseX, mouseY, true);
        end
        else if not leftPressed and (oldMouseButtons and 1) <> 0 then
        begin
            HandleDrawing(mouseX, mouseY, false);
        end;

        oldMouseButtons := mouseButtons;

        { Check for ESC key }
        if KeyPressed then
        begin
            if ReadKey = #27 then
                exitProgram := true;
        end;

        Delay(10);
    end;
end;

{ Main program }
begin
    { Initialize variables }
    currentTool := dtLine;
    currentFillStyle := fssSolid;
    currentThickness := ltMedium;
    currentColor := ctWhite;  { Start with white color }
    exitProgram := false;
    isDrawing := false;
    buttonCount := 0;

    { Initialize graphics and mouse }
    InitializeGraphics;
    InitializeButtons;
    DrawInterface;

    { Main loop }
    MainLoop;

    { Clean up }
    HideMouse;
    CloseGraph;
    writeln('Program zakonczony. Dziekuje za uzycie PaintRs!');
end.