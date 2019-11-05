PROGRAM CurveFever;

USES
    Math, SDL, SDL_gfx, SDL_ttf, SDL_image;

CONST
  SCREEN_W = 800;
  SCREEN_H = 600;
  SCREEN_BPP = 32;
  MOVE_TIME = 25; // Na 25 milisekundi pomeranje.
  DRAW_TIME = 20; // Na 20 milisekundi crtanje.
  POWER_UP_TIME = 7500; // Vreme za koje se pojavljuje power up.
  POWER_UP_TICK_TIME = 100; // Vreme trajanja power up-a.

  INITIAL_NO_DRAW_TIME = 2000; // Prve dve sekunde ne crta.
  STANDARD_NO_DRAW_BASE_TIME = 300;

  ANGLE_DIVISOR = 40;

  ROUND_FONT_PATH = 'font.ttf'; //slova
  ROUND_FONT_SIZE = 30;

  PAUSE_FONT_PATH = 'font.ttf';
  PAUSE_FONT_SIZE = 80;

  ROUND_START_FONT_PATH = 'font.ttf';
  ROUND_START_FONT_SIZE = 80;

  GAME_OVER_FONT_PATH = 'font.ttf';
  GAME_OVER_FONT_SIZE = 80;

  MAIN_MENU_TITLE_FONT_PATH = 'font2.ttf';
  MAIN_MENU_TITLE_FONT_SIZE = 120;
  MAIN_MENU_MSG_FONT_PATH = 'font.ttf';
  MAIN_MENU_MSG_FONT_SIZE = 30;

  MAIN_MENU_MSG_BLINK_TIME = 750;

  // Slike za power up.
  POWERUP_ERASE_IMG_PATH = 'erase_blue.png';
  POWERUP_SELF_SPEED_UP_PATH = 'speed_up_green.png';
  POWERUP_SELF_SLOW_DOWN_PATH = 'slow_down_green.png';
  POWERUP_OPONENT_SPEED_UP_PATH = 'speed_up_red.png';
  POWERUP_OPONENT_SLOW_DOWN_PATH = 'slow_down_red.png';
  POWERUP_WALLS_IMG_PATH = 'walls_blue.png';
  POWERUP_OPONENT_SWITCH_IMG_PATH = 'switch_red.png';

  POWERUP_NUM_TYPES = 7; // Broj power up-a.
  MAX_POWER_UPS = 15;    // Max broj power up-a.
  POWER_UP_INITIAL_TIME = 180; // Trajanje power up-a.

  ORIGINAL_SPEED = 2;
  SPEED_UP_FACTOR = 1.4;

////////////////////////////////////////////////////////////////////////////////
//         GRAFIKA
////////////////////////////////////////////////////////////////////////////////

VAR
  screen : PSDL_Surface; // PSDL_Surface je pokazivac na SDL_Surface.

FUNCTION InitGraphics: boolean;
begin
  InitGraphics := true;
  // SDL Init cita SDL.dll i uzima sve sto mu treba.
  if SDL_Init(SDL_INIT_VIDEO or SDL_INIT_TIMER) <> 0 then InitGraphics := false
  else begin
    // Postavlja title prozora (long title i short title).
    SDL_WM_SetCaption(PChar('CurveFever'), PChar('CurveFever'));
    // otvaramo prozor, vraca pokazivac na SDL_Surface, ako vrati nil, to je greska
    screen := SDL_SetVideoMode(SCREEN_W, SCREEN_H, SCREEN_BPP,
                               SDL_HWSURFACE or SDL_DOUBLEBUF or SDL_HWACCEL);
    if screen = nil then InitGraphics := false;
  end;
  // TTF Init je inicijalizacija za biblioteku za rad sa tekstom SDL_ttf.
  if InitGraphics and (TTF_INIT = -1) then InitGraphics := false;
end;

PROCEDURE CleanUp; // Oslobadja memoriju i brise surface.
begin
  SDL_FreeSurface(screen);
  TTF_Quit;
  SDL_Quit;
end;

//PROCEDURE SetPixel(x, y: integer; R, G, B, A: byte; surface: PSDL_Surface);
//var
//  pixel: ^UInt32;
//begin
//  if not ((x < 0) or (y < 0) or (x >= surface^.w) or (y >= surface^.h)) then
//  begin
//     pixel := surface^.pixels + (y * surface^.w + x) * 4;
//     pixel^ := SDL_MapRGBA(surface^.format, R, G, B, A);
//  end;
//end;

FUNCTION GetPixel(x, y: integer; surface: PSDL_Surface): UInt32; // Uzima pixele.
var
  pixel: ^UInt32;
begin
  if (y < 0) or (x < 0) or (y >= surface^.h) or (x >= surface^.w) then begin
     GetPixel := 0;
  end
  else begin
    pixel := surface^.pixels + (y * surface^.w + x) * 4;
    GetPixel := pixel^;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
//         LOGIKA IGRE
////////////////////////////////////////////////////////////////////////////////

TYPE
  TLeftRight = ( LEFT, RIGHT );

  TPlayer = record
    px, py, x, y, angle, speed : real;
    radius: integer;
    R, G, B: byte;
    color: UInt32;
    steering_dir: TLeftRight; //smer skretanja
    steering: boolean; // Dal skrece.
    switched: boolean; // Dal su okrenuti smerovi.
  end;

  TPowerUp = record
    x, y: integer;
    // 0 - niko
    // 1 - P1
    // 2 - P2
    // 3 - Zajednicko
    owner: integer;
    // 1 - erase
    // 2 - self speed up
    // 3 - self slow down
    // 4 - oponent speed up
    // 5 - oponent slow down
    // 6 - walls
    // 7 - oponent switch
    kind: integer;
    time_left: integer;
  end;

  PPowerUp = ^TPowerUp;

VAR
  power_up_images : array [1..POWERUP_NUM_TYPES] of PSDL_Surface;

FUNCTION FileExists(path: string):boolean;
var
  f : text;
begin
  assign(f, path);
  {$I-}
  reset(f);
  {$I+}
  if (IOResult = 0) then begin
    close(f);
    FileExists := true;
  end
  else FileExists := false;
end;

FUNCTION LoadImage(path: string): PSDL_Surface;
begin
  if (FileExists(path)) then LoadImage := IMG_Load(PChar(path))
  else LoadImage := nil;
end;

FUNCTION LoadResources: boolean;
begin
  LoadResources := true;

  power_up_images[1] := LoadImage(POWERUP_ERASE_IMG_PATH);
  LoadResources := LoadResources and (power_up_images[1] <> nil);

  power_up_images[2] := LoadImage(POWERUP_SELF_SPEED_UP_PATH);
  LoadResources := LoadResources and (power_up_images[2] <> nil);

  power_up_images[3] := LoadImage(POWERUP_SELF_SLOW_DOWN_PATH);
  LoadResources := LoadResources and (power_up_images[3] <> nil);

  power_up_images[4] := LoadImage(POWERUP_OPONENT_SPEED_UP_PATH);
  LoadResources := LoadResources and (power_up_images[4] <> nil);

  power_up_images[5] := LoadImage(POWERUP_OPONENT_SLOW_DOWN_PATH);
  LoadResources := LoadResources and (power_up_images[5] <> nil);

  power_up_images[6] := LoadImage(POWERUP_WALLS_IMG_PATH);
  LoadResources := LoadResources and (power_up_images[6] <> nil);

  power_up_images[7] := LoadImage(POWERUP_OPONENT_SWITCH_IMG_PATH);
  LoadResources := LoadResources and (power_up_images[7] <> nil);
end;

PROCEDURE CleanUpResources;
var
  i : integer;
begin
  for i := 1 to POWERUP_NUM_TYPES do SDL_FreeSurface(power_up_images[i]);
end;

VAR
  Player1, Player2: TPlayer;
  PowerUps: array[1..MAX_POWER_UPS] of PPowerUp;
  nPowerUps: integer;

PROCEDURE InitPlayers(surface: PSDL_Surface);
const
  border_offset = 50; // koliko moraju da budu odmaknuti od ivice
  min_player_dist = 40; // min rastojanje izmedju igraca na pocetku
begin
  with Player1 do begin
    radius := 3;
    R := 255;
    G := 156;
    B := 243;
    // SDL_MapRGB od R, G, B daje UInt32 vrednost po formatu sadrzanom u surface slogu.
    color := SDL_MapRGB(surface^.format, R, G, B);
    angle := random(ANGLE_DIVISOR) * 2 * pi / ANGLE_DIVISOR;
    speed := ORIGINAL_SPEED;
    steering := false;
    switched := false;

    // "beskonacno" daleko
    px := -1000;
    py := -1000;

    repeat
      x := random(surface^.w);
    until (x - radius > border_offset) and
          (x + radius < surface^.w - border_offset);
    repeat
      y := random(surface^.h);
    until (y - radius > border_offset) and
          (y + radius < surface^.h - border_offset);
  end;

  with Player2 do begin
    radius := 3;
    R := 255;
    G := 165;
    B := 0;
    color := SDL_MapRGB(surface^.format, R, G, B);
    angle := random(ANGLE_DIVISOR) * 2 * pi / ANGLE_DIVISOR;
    speed := ORIGINAL_SPEED;
    steering := false;
    switched := false;

    // "beskonacno" daleko
    px := -1000;
    py := -1000;

    repeat
      repeat
        x := random(surface^.w);
      until (x - radius > border_offset) and
            (x + radius < surface^.w - border_offset);
      repeat
        y := random(surface^.h);
      until (y - radius > border_offset) and
            (y + radius < surface^.h - border_offset);
     until sqrt(sqr(Player1.x - x) + sqr(Player1.y - y))
          > Player1.radius + radius + min_player_dist;
  end;
end;

PROCEDURE InitPowerUps;
var
  i: integer;
begin
  for i := 1 to MAX_POWER_UPS do PowerUps[i] := nil;
end;

PROCEDURE ClearPowerUps;
var
  i: integer;
begin
  for i := 1 to MAX_POWER_UPS do if PowerUps[i] <> nil then begin
    dispose(PowerUps[i]);
    PowerUps[i] := nil;
  end;
  nPowerUps := 0;
end;

// Stvara power up na praznom delu povrsine.
FUNCTION GeneratePowerUp(n_tries: integer; surface: PSDL_Surface): PPowerUp;
var
  x, y, i, j : integer;
  ok : boolean;
begin
  GeneratePowerUp := nil;
  while n_tries > 0 do begin
    n_tries := n_tries - 1;
    x := random(surface^.w - 32) + 16;
    y := random(surface^.h - 32) + 16;
    ok := true;
    for i := x - 16 to x + 16 do begin
      for j := y - 16 to y + 16 do if sqrt(sqr(i - x) + sqr(j - y)) <= 16 then
          if GetPixel(i,j, surface) <> 0 then begin
             ok := false;
             break;
          end;
      if not ok then break;
    end;
    if not ok then continue;
    new(GeneratePowerUp);
    GeneratePowerUp^.x := x;
    GeneratePowerUp^.y := y;
    GeneratePowerUp^.kind := random(POWERUP_NUM_TYPES) + 1;
    GeneratePowerUp^.time_left := -1;
    GeneratePowerUp^.owner := 0;
  end;
end;

PROCEDURE DrawPlayers(surface: PSDL_Surface; first_draw: boolean);
var
  sx, sy, ex, ey: integer;
begin
  with Player1 do begin
    //crta pun krug
    filledCircleRGBA(surface, floor(x), floor(y), radius, R, G, B, 255);
    //crta kruznicu sa anti-aliasing
    aacircleRGBA(surface, floor(x), floor(y), radius, R, G, B, 255);
  end;
  with Player2 do begin
    filledCircleRGBA(surface, floor(x), floor(y), radius, R, G, B, 255);
    aacircleRGBA(surface, floor(x), floor(y), radius, R, G, B, 255);
  end;
  //smernice na pocetku
  if first_draw then begin
     with Player1 do begin
       sx := round(x);
       sy := round(y);
       ex := sx + round(cos(angle) * 10);
       ey := sy - round(sin(angle) * 10);
       aalineRGBA(surface, sx, sy, ex, ey, R, G, B, 255);
     end;
     with Player2 do begin
       sx := round(x);
       sy := round(y);
       ex := sx + round(cos(angle) * 10);
       ey := sy - round(sin(angle) * 10);
       aalineRGBA(surface, sx, sy, ex, ey, R, G, B, 255);
     end;
  end;
end;

PROCEDURE DrawPowerUps(game_surface, whole_surface: PSDL_Surface; x_off, y_off: integer);
var
  i: integer;
  r1, r2, r3, r4 : SDL_Rect;
begin
  // kolone
  r1.x := 6; r1.y := 48; r1.w := 32; r1.h := 32;
  r2.x := 54; r2.y := 48; r2.w := 32; r2.h := 32;
  r3.x := 102; r3.y := 48; r3.w := 32; r3.h := 32;

  boxRGBA(screen, 0, 40, 140, whole_surface^.h - 1, 0, 0, 0, 255);

  for i := 1 to MAX_POWER_UPS do if PowerUps[i] <> nil then begin
    with PowerUps[i]^ do begin
      case owner of
        1: begin
           filledPieRGBA(whole_surface, r1.x + 16, r1.y + 16, 21, 270, 269 + round(360 * (time_left / POWER_UP_INITIAL_TIME)), Player1.R, Player1.G, Player1.B, 255);
           SDL_BlitSurface(power_up_images[kind], nil, whole_surface, @r1);
           r1.y := r1.y + 44;
        end;
        2: begin
           filledPieRGBA(whole_surface, r2.x + 16, r2.y + 16, 21, 270, 269 + round(360 * (time_left / POWER_UP_INITIAL_TIME)), Player2.R, Player2.G, Player2.B, 255);
           SDL_BlitSurface(power_up_images[kind], nil, whole_surface, @r2);
           r2.y := r2.y + 44;
        end;
        3: begin
           filledPieRGBA(whole_surface, r3.x + 16, r3.y + 16, 21, 270, 269 + round(360 * (time_left / POWER_UP_INITIAL_TIME)), 45, 114, 136, 255);
           SDL_BlitSurface(power_up_images[kind], nil, whole_surface, @r3);
           r3.y := r3.y + 44;
        end;
        0: begin
           r4.x := x_off + x - 16;
           r4.y := y_off + y - 16;
           r4.w := 32;
           r4.h := 32;

           SDL_BlitSurface(power_up_images[kind], nil, whole_surface, @r4);
        end;
      end;
    end;
  end;
end;

//skretanje jednog igraca
PROCEDURE SteerPlayer(var player: TPlayer);
var
  sign : integer;
begin
  with player do begin
    if switched then sign := -1
    else sign := 1;
    if steering_dir = LEFT then angle := angle + sign * pi / ANGLE_DIVISOR
    else angle := angle - sign * pi / ANGLE_DIVISOR;
    // Vracamo ugao u [0, 2*Pi]
    if angle < 0 then angle := angle + 2 * pi;
    if angle > 2 * pi then angle := angle - 2*pi;
  end;
end;

PROCEDURE MovePlayers(surface: PSDL_Surface);
var
  vx, vy :real;
begin
  with Player1 do begin
    if steering then SteerPlayer(Player1);

    vx := cos(angle) * speed;
    // minus zato sto je obrnut koordinatni sistem
    vy := - sin(angle) * speed;

    px := x;
    py := y;
    x := x + vx;
    y := y + vy;

    if x >= surface^.w then x := x - surface^.w;
    if x < 0 then x := x + surface^.w;

    if y >= surface^.h then y := y - surface^.h;
    if y < 0 then y := y + surface^.h;
  end;

  with Player2 do begin
    if steering then SteerPlayer(Player2);

    vx := cos(angle) * speed;
    vy := - sin(angle) * speed;

    px := x;
    py := y;

    x := x + vx;
    y := y + vy;

    if x >= surface^.w then x := x - surface^.w;
    if x < 0 then x := x + surface^.w;

    if y >= surface^.h then y := y - surface^.h;
    if y < 0 then y := y + surface^.h;
  end;
end;

FUNCTION SelfCollision(var player: TPlayer; surface: PSDL_Surface): boolean;
var
  sx, ex, sy, ey, ix, iy, num_all, num_my_color: integer;
  ratio: real;
begin
  with player do begin
    sx := floor(x) - radius;
    ex := floor(x) + radius;
    sy := floor(y) - radius;
    ey := floor(y) + radius;

    // Broj piksela u krugu
    num_all := 0;
    num_my_color := 0;
    for ix := sx to ex do
    for iy := sy to ey do
      if (sqrt(sqr(ix - x) + sqr(iy - y)) < radius) then begin
        num_all := num_all + 1;
        if (sqrt(sqr(ix - px) + sqr(iy - py)) < radius) then continue;
        if GetPixel(ix, iy, surface) = color
          then num_my_color := num_my_color + 1;
      end;
  end;
  //ratio - odnos broja tacaka u prethodnom tragu, a zahvacenih u novom koraku
  //i ukupnog broja tacka (piksela) u krugu (novoj glavi)
  ratio := num_my_color / num_all;
  SelfCollision := (ratio > 0.4);
end;

// 0 - 00 - nema kolizije
// 1 - 01 - prvi udario
// 2 - 10 - drugi udario
// 3 - 11 - oba udarila
FUNCTION Collision(surface: PSDL_Surface; walls: integer): integer;
var
  p1, p2: boolean;
  sx, ex, sy, ey, ix, iy, num_all, num_op_color: integer;
begin
  with Player1 do begin
    sx := floor(x) - radius;
    ex := floor(x) + radius;
    sy := floor(y) - radius;
    ey := floor(y) + radius;
    p1:=false;
    if walls = 0 then
       p1 := (ex >= surface^.w) or (sx < 0) or
             (ey >= surface^.h) or (sy < 0);

    if not p1 then begin
      num_all := 0;
      num_op_color := 0;
      for ix := sx to ex do
      for iy := sy to ey do
        if sqrt(sqr(ix - x) + sqr(iy - y)) < radius then begin
          num_all := num_all + 1;
          if GetPixel(ix, iy, surface) = Player2.color
            then num_op_color := num_op_color + 1;
        end;
      p1:= (num_op_color / num_all > 0.01);
    end;
    if not p1 then p1 := SelfCollision(Player1, surface);
  end;

  with Player2 do begin
    sx := floor(x) - radius;
    ex := floor(x) + radius;
    sy := floor(y) - radius;
    ey := floor(y) + radius;
    p2:=false;
    if walls = 0 then
       p2 := (ex >= surface^.w) or (sx < 0) or
             (ey >= surface^.h) or (sy < 0);

    if not p2 then begin
      num_all := 0;
      num_op_color := 0;
      for ix := sx to ex do
      for iy := sy to ey do
        if sqrt(sqr(ix - x) + sqr(iy - y)) < radius then begin
          num_all := num_all + 1;
          if GetPixel(ix, iy, surface) = Player1.color
            then num_op_color := num_op_color + 1;
        end;
      p2:= (num_op_color / num_all > 0.01);
    end;
    if not p2 then p2 := SelfCollision(Player2, surface);
  end;

  Collision := 0;
  if p1 then Collision := Collision or 1;
  if p2 then Collision := Collision or 2;
end;

// PlayerID
// 0 - oba
// 1 - p1
// 2 - p2
PROCEDURE HandlePowerUpAction(PlayerID: integer; var PowerUp: PPowerUp; Taking: boolean; saved_surface: PSDL_Surface; var walls: integer);
var
  Player: ^TPlayer;
begin
  case PowerUp^.kind of
    // 1 - erase
    1: begin
       SDL_FillRect(saved_surface, nil, 0);
       dispose(PowerUp);
       PowerUp := nil;
       nPowerUps := nPowerUps - 1;
    end;
    // 2 - self speed up
    2: begin
      if PlayerID = 1 then Player := @Player1;
      if PlayerID = 2 then Player := @Player2;

      PowerUp^.owner := PlayerID;
      PowerUp^.time_left := POWER_UP_INITIAL_TIME;
      if Taking then
        Player^.speed := Player^.speed * SPEED_UP_FACTOR
      else
        Player^.speed := Player^.speed / SPEED_UP_FACTOR;
    end;
    // 3 - self slow down
    3: begin
      if PlayerID = 1 then Player := @Player1;
      if PlayerID = 2 then Player := @Player2;

      PowerUp^.owner := PlayerID;
      PowerUp^.time_left := POWER_UP_INITIAL_TIME;

      if Taking then
         Player^.speed := Player^.speed / SPEED_UP_FACTOR
       else
         Player^.speed := Player^.speed * SPEED_UP_FACTOR;
    end;
    // 4 - oponent speed up
    4: begin
      if PlayerID = 1 then Player := @Player2;
      if PlayerID = 2 then Player := @Player1;

      PowerUp^.owner := PlayerID;
      PowerUp^.time_left := POWER_UP_INITIAL_TIME;
      if Taking then
        Player^.speed := Player^.speed * SPEED_UP_FACTOR
      else
        Player^.speed := Player^.speed / SPEED_UP_FACTOR;
    end;
    // 5 - oponent slow down
    5: begin
      if PlayerID = 1 then Player := @Player2;
      if PlayerID = 2 then Player := @Player1;

      PowerUp^.owner := PlayerID;
      PowerUp^.time_left := POWER_UP_INITIAL_TIME;

       if Taking then
         Player^.speed := Player^.speed / SPEED_UP_FACTOR
       else
         Player^.speed := Player^.speed * SPEED_UP_FACTOR;
    end;
    // 6 - walls
    6: begin
      PowerUp^.owner := 3;
      PowerUp^.time_left := POWER_UP_INITIAL_TIME;

       if Taking then
         walls := walls + 1
       else
         walls := walls - 1;
    end;
    // 7 - oponent switch
    7: begin
      if PlayerID = 1 then Player := @Player2;
      if PlayerID = 2 then Player := @Player1;

      PowerUp^.owner := PlayerID;
      PowerUp^.time_left := POWER_UP_INITIAL_TIME;
      Player^.switched := not Player^.switched;
    end;
  end;

  if not Taking then begin
    dispose(PowerUp);
    PowerUp := nil;
    nPowerUps := nPowerUps - 1;
  end;
end;

PROCEDURE PowerUpCollision(saved_surface: PSDL_Surface; var walls: integer);
var
  i: integer;
begin
  with Player1 do begin
    for i := 1 to MAX_POWER_UPS do if (PowerUps[i] <> nil) and (PowerUps[i]^.owner = 0) then begin
      if sqrt(sqr(PowerUps[i]^.x - x) + sqr(PowerUps[i]^.y - y)) <= 16 + radius then
        HandlePowerUpAction(1, PowerUps[i], true, saved_surface, walls);

    end;
  end;

  with Player2 do begin
    for i := 1 to MAX_POWER_UPS do if (PowerUps[i] <> nil) and (PowerUps[i]^.owner = 0) then begin
      if sqrt(sqr(PowerUps[i]^.x - x) + sqr(PowerUps[i]^.y - y)) <= 16 + radius then
        HandlePowerUpAction(2, PowerUps[i], true, saved_surface, walls);
    end;
  end;
end;

PROCEDURE PauseState;
var
  pause_title_surface, backup_surface: PSDL_Surface;
  font: PTTF_Font;
  font_color: TSDL_Color;
  title_rect: TSDL_Rect; // pravougaonik u kome cemo da ispisemo PAUSE
  event: TSDL_Event;
begin
  backup_surface := SDL_CreateRGBSurface(0, screen^.w, screen^.h,
                                         screen^.format^.BitsPerPixel,
                                         screen^.format^.RMask,
                                         screen^.format^.GMask,
                                         screen^.format^.BMask,
                                         screen^.format^.AMask);
  SDL_BlitSurface(screen, nil, backup_surface, nil);

  boxRGBA(screen, 0, 0, screen^.w - 1, screen^.h - 1, 0, 0, 0, 150);

  font := TTF_OpenFont(PAUSE_FONT_PATH, PAUSE_FONT_SIZE);
  if font = nil then writeln('Greska prilikom citanja fonta.');

  with font_color do begin
    R := 255;
    G := 100;
    B := 150;
  end;

  pause_title_surface := TTF_RENDERTEXT_BLENDED(font, PChar('PAUSE'), font_color);

  with title_rect do begin
    w := pause_title_surface^.w;
    h := pause_title_surface^.h;
    x := (screen^.w - w) div 2;
    y := (screen^.h - h) div 2;
  end;

  SDL_BlitSurface(pause_title_surface, nil, screen, @title_rect);

  SDL_Flip(screen);

  while true do begin
    if (SDL_PollEvent(@event) = 1) and (event.type_ = SDL_KEYDOWN) then break;
  end;

  SDL_BlitSurface(backup_surface, nil, screen, nil);
  SDL_Flip(screen);

  SDL_FreeSurface(pause_title_surface);
  SDL_FreeSurface(backup_surface);
end;

PROCEDURE RoundStartState;
var
  title_surface, backup_surface: PSDL_Surface;
  font: PTTF_Font;
  font_color: TSDL_Color;
  title_rect: TSDL_Rect; // pravougaonik u kome cemo da ispisemo PAUSE
  starts_in: integer;
  starts_in_string: string;
begin
  backup_surface := SDL_CreateRGBSurface(0, screen^.w, screen^.h,
                                         screen^.format^.BitsPerPixel,
                                         screen^.format^.RMask,
                                         screen^.format^.GMask,
                                         screen^.format^.BMask,
                                         screen^.format^.AMask);
  SDL_BlitSurface(screen, nil, backup_surface, nil);

  font := TTF_OpenFont(ROUND_START_FONT_PATH, ROUND_START_FONT_SIZE);
  if font = nil then writeln('Greska prilikom citanja fonta.');

  with font_color do begin
    R := 255;
    G := 100;
    B := 150;
  end;

  starts_in := 3;
  while starts_in > 0 do begin
    boxRGBA(screen, 0, 0, screen^.w - 1, screen^.h - 1, 0, 0, 0, 150);

    str(starts_in, starts_in_string);
    title_surface := TTF_RENDERTEXT_BLENDED(font, PChar(concat('ROUND STARTS IN: ', starts_in_string)), font_color);

    with title_rect do begin
      w := title_surface^.w;
      h := title_surface^.h;
      x := (screen^.w - w) div 2;
      y := (screen^.h - h) div 2;
    end;

    SDL_BlitSurface(title_surface, nil, screen, @title_rect);
    SDL_Flip(screen);

    SDL_Delay(1000);
    SDL_BlitSurface(backup_surface, nil, screen, nil);
    starts_in := starts_in - 1;
  end;

  SDL_Flip(screen);

  SDL_FreeSurface(title_surface);
  SDL_FreeSurface(backup_surface);
end;

PROCEDURE GameOverState(winner_id: integer; var winner: TPlayer);
var
  title_surface, backup_surface: PSDL_Surface;
  font: PTTF_Font;
  font_color: TSDL_Color;
  title_rect: TSDL_Rect;
  winner_id_string: string;
  event: TSDL_Event;
begin
  backup_surface := SDL_CreateRGBSurface(0, screen^.w, screen^.h,
                                         screen^.format^.BitsPerPixel,
                                         screen^.format^.RMask,
                                         screen^.format^.GMask,
                                         screen^.format^.BMask,
                                         screen^.format^.AMask);
  SDL_BlitSurface(screen, nil, backup_surface, nil);

  font := TTF_OpenFont(GAME_OVER_FONT_PATH, GAME_OVER_FONT_SIZE);
  if font = nil then writeln('Greska prilikom citanja fonta.');

  with font_color do begin
    R := winner.R;
    G := winner.G;
    B := winner.B;
  end;

  boxRGBA(screen, 0, 0, screen^.w - 1, screen^.h - 1, 0, 0, 0, 150);

  str(winner_id, winner_id_string);
  title_surface := TTF_RENDERTEXT_BLENDED(font, PChar('Player' + winner_id_string + ' won!'), font_color);

  with title_rect do begin
    w := title_surface^.w;
    h := title_surface^.h;
    x := (screen^.w - w) div 2;
    y := (screen^.h - h) div 2;
  end;

  SDL_BlitSurface(title_surface, nil, screen, @title_rect);
  SDL_Flip(screen);

  SDL_Delay(100);

  while true do begin
    if (SDL_PollEvent(@event) = 1) and (event.type_ = SDL_KEYDOWN) then break;
  end;

  SDL_FillRect(screen, nil, 0);
  SDL_Flip(screen);

  SDL_FreeSurface(title_surface);
  SDL_FreeSurface(backup_surface);
end;

// -1 - prekid igre
//  0 - nereseno
//  1 - prvi pobedio
//  2 - drugi pobedio
FUNCTION OneRound(screen, surface: PSDL_Surface): integer;
var
  running, drawing, initial_no_draw: boolean;
  event: TSDL_Event;
  timer_power_up_tick, timer_power_up, timer_move, timer_draw, timer_initial_no_draw, timer_standard_no_draw, standard_no_draw_time: UInt32;
  where: SDL_Rect;
  saved_surface: PSDL_Surface;
  should_generate_powerup: boolean;
  idx, i, walls: integer;
begin
  saved_surface := SDL_CreateRGBSurface(0, surface^.w, surface^.h,
                                        surface^.format^.BitsPerPixel,
                                        surface^.format^.RMask,
                                        surface^.format^.GMask,
                                        surface^.format^.BMask,
                                        surface^.format^.AMask);

  where.w := surface^.w;
  where.h := surface^.h;
  where.x := 150;
  where.y := 50;

  InitPlayers(surface);
  InitPowerUps;
  DrawPlayers(surface, true);

  boxRGBA(screen, 140, 40, 760, 560, 255, 255, 255, 255);
  SDL_BlitSurface(surface, nil, screen, @where);
  SDL_Flip(screen);
  RoundStartState;
  SDL_Delay(500);

  running := true;
  timer_draw := 0;
  timer_move := 0;
  timer_power_up := SDL_GetTicks;
  timer_power_up_tick := SDL_GetTicks;

  timer_initial_no_draw := SDL_GetTicks + INITIAL_NO_DRAW_TIME;
  drawing := false;
  initial_no_draw := true;
  should_generate_powerup := false;
  walls := 0;


  while running do begin
    if SDL_PollEvent(@event) = 1 then begin
      case event.type_ of
        SDL_QUITEV: begin
          OneRound := -1;
          running := false;
          break;
        end;
        SDL_KEYDOWN: begin
          case event.key.keysym.sym of
            SDLK_S: begin
              with Player1 do begin
                steering := true;
                steering_dir := LEFT;
              end;
            end;
            SDLK_D: begin
              with Player1 do begin
                steering := true;
                steering_dir := RIGHT;
              end;
            end;
            SDLK_Left: begin
              with Player2 do begin
                steering := true;
                steering_dir := LEFT;
              end;
            end;
            SDLK_Right: begin
              with Player2 do begin
                steering := true;
                steering_dir := RIGHT;
              end;
            end;
            SDLK_P: begin
              Player1.steering := false;
              Player2.steering := false;
              PauseState;
            end;
          end;
        end;
        SDL_KEYUP: begin
          case event.key.keysym.sym of
            SDLK_S, SDLK_D: begin
              Player1.steering := false;
            end;
            SDLK_Left, SDLK_Right: begin
              Player2.steering := false;
            end;
          end;
        end;
      end;
    end;

    if (SDL_GetTicks - timer_move > MOVE_TIME) then begin
      timer_move := SDL_GetTicks;
      MovePlayers(surface);
      running := false;
      PowerUpCollision(saved_surface, walls);
      case Collision(surface, walls) of
        0: running := true;
        1: OneRound := 2;
        2: OneRound := 1;
        3: OneRound := 0;
      end;
    end;

    if (SDL_GetTicks - timer_draw > DRAW_TIME) then begin
      timer_draw := SDL_GetTicks;

      if drawing and (random > 0.995) then begin
         drawing := false;
         timer_standard_no_draw := SDL_GetTicks;
         standard_no_draw_time := STANDARD_NO_DRAW_BASE_TIME * (random(2) + 1);
         SDL_BlitSurface(surface, nil, saved_surface, nil);
      end;

      SDL_BlitSurface(saved_surface, nil, surface, nil);
      DrawPlayers(surface, false);
      if drawing then SDL_BlitSurface(surface, nil, saved_surface, nil);
      // Nalepljuje jednu povrsinu preko druge.
      SDL_BlitSurface(surface, nil, screen, @where);

      DrawPowerUps(surface, screen, where.x, where.y);

      SDL_Flip(screen);
    end;

    if (SDL_GetTicks - timer_power_up > POWER_UP_TIME) then begin
      if (nPowerUps < MAX_POWER_UPS) then begin
        should_generate_powerup := true;
        idx := 1;
        while (PowerUps[idx] <> nil) do idx := idx + 1;
      end;
    end;

    if should_generate_powerup then begin
       PowerUps[idx] := GeneratePowerUp(3, surface);
       if (PowerUps[idx] <> nil) then begin
         nPowerUps := nPowerUps + 1;
         should_generate_powerup := false;
         timer_power_up := SDL_GetTicks;
       end;
    end;

    if (SDL_GetTicks - timer_power_up_tick > POWER_UP_TICK_TIME) then begin
      timer_power_up_tick := SDL_GetTicks;
      for i := 1 to MAX_POWER_UPS do if (PowerUps[i] <> nil) and (PowerUps[i]^.owner <> 0) then begin
        PowerUps[i]^.time_left := PowerUps[i]^.time_left-1;
        if (PowerUps[i]^.time_left <= 0) then begin
          if PowerUps[i]^.owner = 3 then PowerUps[i]^.owner := 0;
          HandlePowerUpAction(PowerUps[i]^.owner, PowerUps[i], false, saved_surface, walls);
        end;
      end;
    end;

    if initial_no_draw and (SDL_GetTicks - timer_initial_no_draw > INITIAL_NO_DRAW_TIME) then begin
       drawing := true;
       initial_no_draw := false;
    end;

    if not initial_no_draw and (SDL_GetTicks - timer_standard_no_draw > standard_no_draw_time) then
       drawing := true;
  end;
  ClearPowerUps;
  SDL_FreeSurface(saved_surface);
end;

PROCEDURE SideBar(p1p, p2p: integer;
                  font: PTTF_Font;
                  var font_color_p1, font_color_p2: TSDL_Color);
var
  where_p1_surface, where_p2_surface: TSDL_Rect;
  p1p_string, p2p_string: string;
  p1_surface, p2_surface: PSDL_SURFACE;
begin

  with where_p1_surface do begin
    x := 10; y := 10; w := 0; h := 0;
  end;

  with where_p2_surface do begin
    x := 60; y := 10; w := 0; h := 0;
  end;

  boxRGBA(screen, 0, 0, 140, screen^.h - 1, 0, 0, 0, 255);

  str(p1p, p1p_string);
  str(p2p, p2p_string);
  // Pravi surface sa tekstom od fonta, stringa i boje.
  // Pchar je imitacija c-ovskog stringa, to sad mozes da zaboravis.
  p1_surface := TTF_RENDERTEXT_BLENDED(font, PChar(p1p_string), font_color_p1);
  p2_surface := TTF_RENDERTEXT_BLENDED(font, PChar(p2p_string), font_color_p2);
  where_p1_surface.w := p1_surface^.w;
  where_p1_surface.h := p1_surface^.h;
  SDL_BlitSurface(p1_surface, nil, screen, @where_p1_surface);
  where_p2_surface.w := p2_surface^.w;
  where_p2_surface.h := p2_surface^.h;
  SDL_BlitSurface(p2_surface, nil, screen, @where_p2_surface);
  SDL_FreeSurface(p1_surface);
  SDL_FreeSurface(p2_surface);
  SDL_Flip(screen);
end;

// -1 - prekid igre
//  1 - prvi pobedio
//  2 - drugi pobedio
FUNCTION AllRounds(screen: PSDL_Surface): integer;
var
  game_surface: PSDL_Surface;
  font: PTTF_Font;
  font_color_p1, font_color_p2: TSDL_Color;
  p1p, p2p, point_limit, round_num: integer;

begin
  game_surface := SDL_CreateRGBSurface(0, 600, 500,
                                         screen^.format^.BitsPerPixel,
                                         screen^.format^.RMask,
                                         screen^.format^.GMask,
                                         screen^.format^.BMask,
                                         screen^.format^.AMask);

  // Ucitava font iz fajla.
  font := TTF_OpenFont(ROUND_FONT_PATH, ROUND_FONT_SIZE);
  if font = nil then writeln('Greska prilikom citanja fonta.');

  with font_color_p1 do begin
    r := 255;
    g := 156;
    b := 243;
  end;

  with font_color_p2 do begin
    r := 255;
    g := 165;
    b := 0;
  end;

  point_limit := 5;
  p1p := 0; p2p := 0;
  round_num := 0;
  // cistim ekran
  SDL_FillRect(screen, nil, 0);
  SideBar(p1p, p2p, font, font_color_p1, font_color_p2);
  while (p1p < point_limit) and (p2p < point_limit) do begin
    round_num := round_num + 1;

    case OneRound(screen, game_surface) of
      -1: break; // izlazak iz igre
      0: begin
         writeln(round_num, ' : Nereseno');
      end;
      1: begin
        p1p := p1p + 1;
      end;
      2: begin
        p2p := p2p + 1;
      end;
    end;

    SideBar(p1p, p2p, font, font_color_p1, font_color_p2);

    SDL_FillRect(game_surface, nil, 0);
    SDL_Delay(1000);
  end;

  if p1p = point_limit then AllRounds := 1
  else if p2p = point_limit then AllRounds := 2
  else AllRounds := -1;

  SDL_FreeSurface(game_surface);
end;

FUNCTION Brightness(r, g, b: Byte): real; // [0, 1]
begin
  Brightness := sqrt( 0.299*r*r + 0.587*g*g + 0.114*b*b) / 255;
end;

// 0 - izadji
// 1 - igraj
FUNCTION MainMenu: integer;
var
  game_title_surface, msg_surface {Press <ENTER> to play}: PSDL_Surface;
  game_title_rect, msg_rect: TSDL_Rect;
  game_title_font, msg_font: PTTF_Font;
  font_color: TSDL_Color;
  r, g, b: Byte;

  event: TSDL_Event;
  timer_blink: UInt32;
  msg_visible: boolean;
begin
  repeat
    r := random(256);
    g := random(256);
    b := random(256);
  until Brightness(r, g, b) > 0.5;

  game_title_font := TTF_OpenFont(MAIN_MENU_TITLE_FONT_PATH, MAIN_MENU_TITLE_FONT_SIZE);
  if game_title_font = nil then writeln('Greska prilikom citanja fonta.');

  msg_font := TTF_OpenFont(MAIN_MENU_MSG_FONT_PATH, MAIN_MENU_MSG_FONT_SIZE);
  if msg_font = nil then writeln('Greska prilikom citanja fonta.');

  with font_color do begin
    R := 0;
    G := 0;
    B := 0;
  end;

  game_title_surface := TTF_RENDERTEXT_BLENDED(game_title_font, PChar('CurveFever'), font_color);
  msg_surface := TTF_RENDERTEXT_BLENDED(msg_font, PChar('Press Enter to play.'), font_color);

  with game_title_rect do begin
    w := game_title_surface^.w;
    h := game_title_surface^.h;
    x := (screen^.w - w) div 2;
    y := (screen^.h - h) div 3;
  end;

  with msg_rect do begin
    w := msg_surface^.w;
    h := msg_surface^.h;
    x := (screen^.w - w) div 2;
    y := (screen^.h div 5) * 4;
  end;

  timer_blink := 0;
  msg_visible := false;

  while true do begin
    if SDL_PollEvent(@event) = 1 then begin
      case event.type_ of
        SDL_QUITEV: begin
          MainMenu := 0;
          break;
        end;
        SDL_KEYDOWN: begin
          case event.key.keysym.sym of
            SDLK_RETURN: begin
              MainMenu := 1;
              break;
            end;
          end;
        end;
      end;
    end;

    if (SDL_GetTicks - timer_blink > MAIN_MENU_MSG_BLINK_TIME) then begin
      timer_blink := SDL_GetTicks;
      msg_visible := not msg_visible;

      boxRGBA(screen, 0, 0, screen^.w - 1, screen^.h - 1, r, g, b, 255);
      SDL_BlitSurface(game_title_surface, nil, screen, @game_title_rect);
      if msg_visible then SDL_BlitSurface(msg_surface, nil, screen, @msg_rect);
      SDL_Flip(screen);
    end;
  end;

  SDL_FreeSurface(game_title_surface);
  SDL_FreeSurface(msg_surface);
end;

BEGIN
  if not InitGraphics then writeln('Greska u InitGraphics.')
  else if not LoadResources then writeln('Greska u ucitavanju resursa.')
  else begin
    randomize;
    while MainMenu = 1 do begin
      case AllRounds(screen) of
       -1: break;
        1: GameOverState(1, Player1);
        2: GameOverState(2, Player2);
      end;
    end;
    CleanUpResources;
    CleanUp;
  end;
END.

