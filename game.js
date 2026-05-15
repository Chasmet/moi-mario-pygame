const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

let player = { x: 80, y: 300, w: 55, h: 75, velY: 0, speed: 6, jumping: false };
let keys = {};
let cameraX = 0;
let gravity = 0.85;
let score = 0;
let gameOver = false;

// Ta photo Naruto
let playerImg = new Image();
playerImg.src = 'player.png';

// Ennemis Goomba
let enemies = [
    {x: 650, y: 380, w: 48, h: 48, velX: -2.2},
    {x: 1150, y: 380, w: 48, h: 48, velX: -2.2}
];

let platforms = [
    {x:0, y:430, w:2000, h:70},
    {x:280, y:340, w:160, h:25},
    {x:520, y:260, w:160, h:25},
    {x:820, y:340, w:160, h:25},
    {x:1250, y:280, w:160, h:25}
];

let pipe = {x: 1550, y: 370, w: 85, h: 110};

// Touch controls
let touchLeft = false, touchRight = false, touchJump = false;

const leftBtn = document.getElementById('leftBtn');
const rightBtn = document.getElementById('rightBtn');
const jumpBtn = document.getElementById('jumpBtn');

leftBtn.addEventListener('touchstart', () => touchLeft = true);
leftBtn.addEventListener('touchend', () => touchLeft = false);
rightBtn.addEventListener('touchstart', () => touchRight = true);
rightBtn.addEventListener('touchend', () => touchRight = false);
jumpBtn.addEventListener('touchstart', () => { if (!player.jumping) { player.velY = -19; player.jumping = true; } });

// Clavier
document.addEventListener('keydown', e => keys[e.key.toLowerCase()] = true);
document.addEventListener('keyup', e => keys[e.key.toLowerCase()] = false);

function update() {
    if (gameOver) return;

    // Mouvement
    if (keys['arrowleft'] || keys['q'] || touchLeft) player.x -= player.speed;
    if (keys['arrowright'] || keys['d'] || touchRight) player.x += player.speed;

    // Saut
    if ((keys[' '] || keys['arrowup']) && !player.jumping) {
        player.velY = -19;
        player.jumping = true;
    }

    // Gravité
    player.velY += gravity;
    player.y += player.velY;

    // Collisions plateformes
    player.jumping = true;
    for (let p of platforms) {
        if (player.x + player.w > p.x && player.x < p.x + p.w &&
            player.y + player.h > p.y && player.y + player.h - player.velY <= p.y + 10) {
            player.y = p.y - player.h;
            player.velY = 0;
            player.jumping = false;
        }
    }

    // Limites
    if (player.y > 600) {
        gameOver = true;
    }
    if (player.x < cameraX + 30) player.x = cameraX + 30;

    // Scrolling
    if (player.x > cameraX + 450) cameraX = player.x - 450;

    // Ennemis
    enemies.forEach(e => {
        e.x += e.velX;
        if (e.x < 300) e.velX = 2.5;
        if (e.x > 1700) e.velX = -2.5;

        // Collision ennemi
        if (player.x + player.w > e.x && player.x < e.x + e.w &&
            player.y + player.h > e.y && player.y < e.y + e.h) {
            if (player.velY > 0 && player.y + player.h - player.velY < e.y + 10) {
                // Écrase l'ennemi
                e.x = -100;
                score += 200;
            } else {
                gameOver = true;
            }
        }
    });

    score += 1;
}

function draw() {
    ctx.fillStyle = '#5C94FC';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.save();
    ctx.translate(-cameraX, 0);

    // Sol
    ctx.fillStyle = '#E0B070';
    ctx.fillRect(0, 430, 2500, 100);

    // Plateformes
    ctx.fillStyle = '#E8B76B';
    platforms.forEach(p => ctx.fillRect(p.x, p.y, p.w, p.h));

    // Pipe
    ctx.fillStyle = '#00A000';
    ctx.fillRect(pipe.x, pipe.y, pipe.w, pipe.h);

    // Toi (Naruto avec ta photo)
    if (playerImg.complete) {
        ctx.drawImage(playerImg, player.x, player.y, player.w, player.h);
    } else {
        ctx.fillStyle = '#FF4500';
        ctx.fillRect(player.x, player.y, player.w, player.h);
    }

    // Ennemis
    ctx.fillStyle = '#8B4513';
    enemies.forEach(e => {
        ctx.fillRect(e.x, e.y, e.w, e.h);
        ctx.fillStyle = '#000';
        ctx.fillRect(e.x+10, e.y+15, 12, 12); // yeux
        ctx.fillRect(e.x+28, e.y+15, 12, 12);
    });

    ctx.restore();

    // UI
    ctx.fillStyle = '#FFF';
    ctx.font = 'bold 22px Arial';
    ctx.fillText('Score: ' + Math.floor(score/8), 30, 45);

    if (gameOver) {
        ctx.fillStyle = 'rgba(0,0,0,0.7)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        ctx.fillStyle = '#FF0000';
        ctx.font = 'bold 48px Arial';
        ctx.fillText('GAME OVER', 220, 220);
        ctx.font = 'bold 28px Arial';
        ctx.fillStyle = '#FFF';
        ctx.fillText('Appuie sur R pour recommencer', 140, 280);
    }
}

function loop() {
    update();
    draw();
    requestAnimationFrame(loop);
}

// Restart
document.addEventListener('keydown', e => {
    if (e.key.toLowerCase() === 'r' && gameOver) {
        location.reload();
    }
});

loop();