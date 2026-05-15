const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

let player = { x: 80, y: 300, w: 48, h: 68, velY: 0, speed: 5, onGround: false };
let keys = {};
let cameraX = 0;
let gravity = 0.85;
let score = 0;
let gameOver = false;

let playerImg = new Image();
playerImg.src = 'player.png';

let enemies = [
    { x: 650, y: 390, w: 42, h: 42, velX: -1.8, alive: true },
    { x: 1050, y: 390, w: 42, h: 42, velX: -1.5, alive: true }
];

let platforms = [
    {x:0, y:430, w:2000, h:70},
    {x:280, y:340, w:160, h:20},
    {x:520, y:260, w:140, h:20},
    {x:780, y:360, w:180, h:20},
    {x:1100, y:290, w:150, h:20}
];

let pipe = {x: 1350, y: 370, w: 70, h: 110};

let leftPressed = false;
let rightPressed = false;

function moveLeft(pressed) { leftPressed = pressed; }
function moveRight(pressed) { rightPressed = pressed; }

function jump() {
    if (player.onGround && !gameOver) {
        player.velY = -17;
        player.onGround = false;
    }
}

document.addEventListener('keydown', e => { keys[e.key] = true; if ((e.key === ' ' || e.key === 'ArrowUp') && player.onGround) jump(); });
document.addEventListener('keyup', e => keys[e.key] = false);

function update() {
    if (gameOver) return;

    if (keys['ArrowLeft'] || keys['q'] || keys['Q'] || leftPressed) player.x -= player.speed;
    if (keys['ArrowRight'] || keys['d'] || keys['D'] || rightPressed) player.x += player.speed;

    player.velY += gravity;
    player.y += player.velY;

    player.onGround = false;
    for (let p of platforms) {
        if (player.x < p.x + p.w && player.x + player.w > p.x &&
            player.y + player.h > p.y && player.y + player.h - player.velY <= p.y) {
            player.y = p.y - player.h;
            player.velY = 0;
            player.onGround = true;
        }
    }

    if (player.x < pipe.x + pipe.w && player.x + player.w > pipe.x &&
        player.y < pipe.y + pipe.h && player.y + player.h > pipe.y) {
        player.x = pipe.x - player.w;
    }

    if (player.x > cameraX + 450) cameraX = player.x - 450;
    if (player.x < cameraX + 50) player.x = cameraX + 50;

    enemies.forEach(e => {
        if (e.alive) {
            e.x += e.velX;
            if (e.x < cameraX + 100 || e.x > cameraX + 1400) e.velX *= -1;

            if (player.x < e.x + e.w && player.x + player.w > e.x &&
                player.y < e.y + e.h && player.y + player.h > e.y) {
                if (player.velY > 0 && player.y + player.h - 20 < e.y) {
                    e.alive = false;
                    player.velY = -12;
                    score += 100;
                } else {
                    gameOver = true;
                }
            }
        }
    });

    if (player.y > 550) gameOver = true;

    score += 1;
}

function draw() {
    ctx.fillStyle = '#5C94FC';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.save();
    ctx.translate(-cameraX, 0);

    ctx.fillStyle = '#E8B76B';
    ctx.fillRect(0, 430, 2500, 100);

    ctx.fillStyle = '#C4A484';
    platforms.forEach(p => ctx.fillRect(p.x, p.y, p.w, p.h));

    ctx.fillStyle = '#00A000';
    ctx.fillRect(pipe.x, pipe.y, pipe.w, pipe.h);
    ctx.fillStyle = '#008000';
    ctx.fillRect(pipe.x - 8, pipe.y - 25, pipe.w + 16, 30);

    if (playerImg.complete) {
        ctx.drawImage(playerImg, player.x, player.y, player.w, player.h);
    } else {
        ctx.fillStyle = '#FF4500';
        ctx.fillRect(player.x, player.y, player.w, player.h);
    }

    ctx.fillStyle = '#8B4513';
    enemies.forEach(e => {
        if (e.alive) ctx.fillRect(e.x, e.y, e.w, e.h);
    });

    ctx.restore();

    ctx.fillStyle = '#FFF';
    ctx.font = 'bold 22px Arial';
    ctx.fillText('Score: ' + Math.floor(score / 5), 20, 40);
    ctx.fillText('Super Moi Bros - Naruto', 20, 70);

    if (gameOver) {
        ctx.fillStyle = 'rgba(0,0,0,0.7)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#FF0000';
        ctx.font = 'bold 48px Arial';
        ctx.fillText('GAME OVER', 220, 220);
        ctx.font = '24px Arial';
        ctx.fillStyle = '#FFF';
        ctx.fillText('Appuie sur R pour recommencer', 180, 280);
    }
}

function loop() {
    update();
    draw();
    requestAnimationFrame(loop);
}

document.addEventListener('keydown', e => {
    if (e.key.toLowerCase() === 'r' && gameOver) location.reload();
});

loop();