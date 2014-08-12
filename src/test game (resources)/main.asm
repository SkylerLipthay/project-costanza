- A: p1 y
- B: p2 y
- C: ball x
- D: ball y
- E: ball dx
- F: ball dy
- G: start dir
- H: movement: 3:0 = {p2 down, p2 up, p1 down, p1 up}
- *****************************************************************************
- & load audio
- *****************************************************************************
            lma snd_jazzy
            snda 0
- this next value is in words... one day this will be in bytes
            lma 0x88680
            sndl 0
            sndr 0, 1
            sndw 0
            sndp 0, 1
            lma snd_boom
            snda 1
- this next value is in words... one day this will be in bytes
            lma 0x5A3
            sndl 1
            sndr 1, 0
reset:
            mov RH, R0
            add RG, R1
            mov RX, 0b11
            and RG, RX
            cmp RG, R0
            lma _ball_start_up_right
            bre
            cmp RG, R1
            lma _ball_start_down_left
            bre
            mov RX, 2
            cmp RG, RX
            lma _ball_start_down_right
            bre
-ball_start_up_left:
            mov RE, -26
            mov RF, -26
            lma _post_ball_start
            br
_ball_start_up_right:
            mov RE, 26
            mov RF, -26
            lma _post_ball_start
            br
_ball_start_down_left:
            mov RE, -26
            mov RF, 26
            lma _post_ball_start
            br
_ball_start_down_right:
            mov RE, 26
            mov RF, 26
            lma _post_ball_start
            br
_post_ball_start:
            mov RA, 90
            mov RB, 90
            mov RC, 2384
            mov RD, 1680
main:
- *****************************************************************************
- & ball bounds
- *****************************************************************************
            mov RX, 33
            cmp RD, RX
            lma _check_low
            brae
            mov RD, 35
            neg RF
_check_low:
            mov RX, 3345
            cmp RX, RD
            lma _post_bounds
            brae
            mov RD, 3343
            neg RF
_post_bounds:
- *****************************************************************************
- & move ball
- *****************************************************************************
            add RC, RE
            add RD, RF
- *****************************************************************************
- & move p1
- *****************************************************************************
            mov RX, J1
            mov RY, 0b1
            and RX, RY
            cmp RX, R0
            lma _p1_down
            bre
            cmp RA, R0
            lma _p1_down
            bre
            mov RY, 3
            sub RA, RY
            mov RX, 0b1
            or RH, RX
_p1_down:
            mov RX, J1
            mov RY, 0b10
            and RX, RY
            cmp RX, R0
            lma _post_p1_move
            bre
            mov RY, 180
            cmp RA, RY
            lma _post_p1_move
            bre
            mov RY, 3
            add RA, RY
            mov RX, 0b01
            or RH, RX
_post_p1_move:
- *****************************************************************************
- & move p2
- *****************************************************************************
            mov RX, J2
            mov RY, 0b1
            and RX, RY
            cmp RX, R0
            lma _p2_down
            bre
            cmp RB, R0
            lma _p2_down
            bre
            mov RY, 3
            sub RB, RY
            mov RX, 0b001
            or RH, RX
_p2_down:
            mov RX, J2
            mov RY, 0b10
            and RX, RY
            cmp RX, R0
            lma _post_p2_move
            bre
            mov RY, 180
            cmp RB, RY
            lma _post_p2_move
            bre
            mov RY, 3
            add RB, RY
            mov RX, 0b0001
            or RH, RX
_post_p2_move:
- *****************************************************************************
- & collision p1
- *****************************************************************************
            mov RX, 272
            cmp RX, RC
            lma _post_p1_coll
            brae
-
            mov RX, 368
            cmp RC, RX
            lma _post_p1_coll
            brae
-
            mov RX, RD
            shr RX
            shr RX
            shr RX
            shr RX
            mov RY, 30
            add RX, RY
            cmp RA, RX
            lma _post_p1_coll
            brae
-
            mov RX, RD
            shr RX
            shr RX
            shr RX
            shr RX
            mov RY, RA
            mov RML, 60
            add RY, RML
            cmp RX, RY
            lma _post_p1_coll
            brae
-
            neg RE
            mov RC, 368
            sndw 1
            sndp 1, 1
_post_p1_coll:
- *****************************************************************************
- & collision p2
- *****************************************************************************
            mov RX, 4496
            cmp RC, RX
            lma _post_p2_coll
            brae
-
            mov RX, 4400
            cmp RX, RC
            lma _post_p2_coll
            brae
-
            mov RX, RD
            shr RX
            shr RX
            shr RX
            shr RX
            mov RY, 30
            add RX, RY
            cmp RB, RX
            lma _post_p2_coll
            brae
-
            mov RX, RD
            shr RX
            shr RX
            shr RX
            shr RX
            mov RY, RB
            mov RML, 60
            add RY, RML
            cmp RX, RY
            lma _post_p2_coll
            brae
-
            neg RE
            mov RC, 4400
            sndw 1
            sndp 1, 1
_post_p2_coll:
- *****************************************************************************
- & draw background
- *****************************************************************************
            imgd 320, 240
            imgcd 0, 0
            lma img_bg
            imga
- *****************************************************************************
- & draw p1
- *****************************************************************************
            imgd 12, 60
            mov RX, 10
            mov RY, RA
            imgc
            lma img_p1
            imga
- *****************************************************************************
- & draw p1
- *****************************************************************************
            imgd 12, 60
            mov RX, 298
            mov RY, RB
            imgc
            lma img_p2
            imga
- *****************************************************************************
- & draw ball
- *****************************************************************************
            imgd 22, 29
            mov RX, RC
            shr RX
            shr RX
            shr RX
            shr RX
            mov RY, RD
            shr RY
            shr RY
            shr RY
            shr RY
            imgc
            lma img_ball
            imga
- *****************************************************************************
- & flip framebuffer
- *****************************************************************************
            flip
            halt
- *****************************************************************************
- & check score
- *****************************************************************************
            mov RX, -352
            cmp RC, RX
            lma reset
            brle
            mov RX, 4768
            cmp RC, RX
            lma reset
            brae
            lma main
            br
-
- @@@@@@@@@@@@@@@@@@@@@@@           END CODE!           @@@@@@@@@@@@@@@@@@@@@@@
- *****************************************************************************
- & resources
- *****************************************************************************
img_bg:
            rawi "bg.png"
img_ball:
            rawi "ball.png"
img_p1:
            rawi "p1.png"
img_p2:
            rawi "p2.png"
snd_jazzy:
            rawf "ambient.raw"
snd_boom:
            rawf "pop.raw"
- *****************************************************************************
- & SECTOR      data
- *****************************************************************************
p1_x:
            raww 10
p1_y:
            raww 90
p2_x:
            raww 298
p2_y:
            raww 90
- implicit divisor of 16
ball_x:
            raww 2384
ball_y:
            raww 1680
ball_dx:
            raww 32
ball_dy:
            raww 4
start_dir:
            raww 0xFFFF