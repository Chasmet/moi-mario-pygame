const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

const leftBtn = document.getElementById('leftBtn');
const rightBtn = document.getElementById('rightBtn');
const jumpBtn = document.getElementById('jumpBtn');
const restartBtn = document.getElementById('restartBtn');
const overlay = document.getElementById('overlay');
const overlayTitle = document.getElementById('overlayTitle');
const overlayMsg = document.getElementById('overlayMsg');

const scoreVal = document.getElementById('scoreVal');
const livesVal = document.getElementById('livesVal');
const coinsVal = document.getElementById('coinsVal');

// ===================== CONFIG =====================
const GRAVITY = 0.75;
const JUMP_FORCE = -16.5;
const MOVE_SPEED = 5.2;
const FRICTION = 0.82;

let player = {
    x: 80,
    y: 200,
    w: 48,
    h: 64,
    velX: 0,
    velY: 0,
    onGround: false,
    facing: 1
};

let cameraX = 0;
let score = 0;
let coins = 0;
let lives = 3;
let gameState = 'play'; // play | dead | win
let invincible = 0;

const playerImg = new Image();
playerImg.src = 'player.png';

// Level data
const platforms = [
    // Sol principal
    { x: 0, y: 480, w: 3200, h: 80 },
    // Plateformes
    { x: 220, y: 380, w: 140, h: 22 },
    { x: 420, y: 300, w: 140, h: 22 },
    { x: 640, y: 380, w: 120, h: 22 },
    { x: 820, y: 260, w: 160, h: 22 },
    { x: 1080, y: 340, w: 140, h: 22 },
    { x: 1300, y: 250, w: 180, h: 22 },
    { x: 1580, y: 360, w: 130, h: 22 },
    { x: 1800, y: 280, w: 160, h: 22 },
    { x: 2050, y: 200, w: 140, h: 22 },
    { x: 2300, y: 320, w: 200, h: 22 },
    { x: 2600, y: 240, w: 160, h: 22 },
    { x: 2850, y: 360, w: 180, h: 22 }
];

let enemies = [
    { x: 380, y: 440, w: 40, h: 40, velX: -1.8, alive: true },
    { x: 700, y: 440, w: 40, h: 40, velX: 1.6, alive: true },
    { x: 980, y: 440, w: 40, h: 40, velX: -2.0, alive: true },
    { x: 1450, y: 440, w: 40, h: 40, velX: 1.9, alive: true },
    { x: 1900, y: 440, w: 40, h: 40, velX: -1.7, alive: true },
    { x: 2450, y: 440, w: 40, h: 40, velX: 2.1, alive: true },
    { x: 2700, y: 440, w: 40, h: 40, velX: -1.5, alive: true }
];

let coinList = [
    { x: 260, y: 340, collected: false },
    { x: 460, y: 260, collected: false },
    { x: 680, y: 340, collected: false },
    { x: 880, y: 220, collected: false },
    { x: 1120, y: 300, collected: false },
    { x: 1360, y: 210, collected: false },
    { x: 1620, y: 320, collected: false },
    { x: 1860, y: 240, collected: false },
    { x: 2100, y: 160, collected: false },
    { x: 2360, y: 280, collected: false },
    { x: 2650, y: 200, collected: false },
    { x: 2900, y: 320, collected: false }
];

const flag = { x: 3050, y: 320, w: 20, h: 160 };

// ===================== INPUT =====================
let keys = {};
let touchLeft = false;
let touchRight = false;

function bindHold(btn, on, off) {
    const start = (e) => { e.preventDefault(); btn.classList.add('active'); on(); };
    const end = (e) => { e.preventDefault(); btn.classList.remove('active'); off(); };
    ['touchstart', 'mousedown'].forEach(ev => btn.addEventListener(ev, start, { passive: false }));
    ['touchend', 'touchcancel', 'mouseup', 'mouseleave'].forEach(ev => btn.addEventListener(ev, end, { passive: false }));
}

bindHold(leftBtn, () => touchLeft = true, () => touchLeft = false);
bindHold(rightBtn, () => touchRight = true, () => touchRight = false);
bindHold(jumpBtn, () => {
    if (player.onGround && gameState === 'play') {
        player.velY = JUMP_FORCE;
        player.onGround = false;
    }
}, () => {});

restartBtn.addEventListener('click', resetGame);
restartBtn.addEventListener('touchstart', (e) => { e.preventDefault(); resetGame(); }, { passive: false });

document.addEventListener('keydown', e => {
    keys[e.key.toLowerCase()] = true;
    if ((e.key === ' ' || e.key === 'ArrowUp') && player.onGround && gameState === 'play') {
        player.velY = JUMP_FORCE;
        player.onGround = false;
    }
    if (e.key.toLowerCase() === 'r' && gameState !== 'play') resetGame();
});
document.addEventListener('keyup', e => keys[e.key.toLowerCase()] = false);

// ===================== RESIZE =====================
function resize() {
    const ratio = 960 / 540;
    let w = window.innerWidth;
    let h = w / ratio;
    if (h > window.innerHeight) {
        h = window.innerHeight;
        w = h * ratio;
    }
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
}
window.addEventListener('resize', resize);
window.addEventListener('orientationchange', resize);
resize();

// ===================== LOGIC =====================
function resetGame() {
    player.x = 80;
    player.y = 200;
    player.velX = 0;
    player.velY = 0;
    player.onGround = false;
    cameraX = 0;
    score = 0;
    coins = 0;
    lives = 3;
    invincible = 0;
    gameState = 'play';
    overlay.style.display = 'none';

    enemies.forEach(e => { e.alive = true; e.x = e.startX || e.x; });
    // store original positions
    enemies.forEach(e => { if (!e.startX) e.startX = e.x; });
    coinList.forEach(c => c.collected = false);

    updateUI();
}

function updateUI() {
    scoreVal.textContent = score;
    livesVal.textContent = lives;
    coinsVal.textContent = coins;
}

function die() {
    if (invincible > 0) return;
    lives--;
    updateUI();
    if (lives <= 0) {
        gameState = 'dead';
        overlayTitle.textContent = 'GAME OVER';
        overlayMsg.textContent = 'Score final : ' + score;
        overlay.style.display = 'flex';
    } else {
        // respawn
        player.x = Math.max(80, cameraX + 100);
        player.y = 200;
        player.velY = 0;
        invincible = 90;
    }
}

function win() {
    gameState = 'win';
    score += 1000 + coins * 50;
    updateUI();
    overlayTitle.textContent = 'VICTOIRE !';
    overlayMsg.textContent = 'Score : ' + score + ' | Pièces : ' + coins;
    overlay.style.display = 'flex';
}

function update() {
    if (gameState !== 'play') return;

    // Horizontal movement
    let moving = false;
    if (keys['arrowleft'] || keys['q'] || keys['a'] || touchLeft) {
        player.velX = -MOVE_SPEED;
        player.facing = -1;
        moving = true;
    }
    if (keys['arrowright'] || keys['d'] || touchRight) {
        player.velX = MOVE_SPEED;
        player.facing = 1;
        moving = true;
    }
    if (!moving) player.velX *= FRICTION;
    if (Math.abs(player.velX) < 0.3) player.velX = 0;

    player.x += player.velX;

    // Gravity
    player.velY += GRAVITY;
    player.y += player.velY;

    // Platform collisions
    player.onGround = false;
    for (const p of platforms) {
        if (player.x + player.w > p.x && player.x < p.x + p.w) {
            // Landing on top
            if (player.velY >= 0 &&
                player.y + player.h > p.y &&
                player.y + player.h - player.velY <= p.y + 12) {
                player.y = p.y - player.h;
                player.velY = 0;
                player.onGround = true;
            }
        }
    }

    // Fall death
    if (player.y > 600) die();

    // Camera
    if (player.x > cameraX + 380) cameraX = player.x - 380;
    if (player.x < cameraX + 120) cameraX = Math.max(0, player.x - 120);
    cameraX = Math.max(0, Math.min(cameraX, 3200 - 960));

    // Enemies
    enemies.forEach(e => {
        if (!e.alive) return;
        e.x += e.velX;

        // Simple bounce between walls / platforms
        if (e.x < 50 || e.x > 3100) e.velX *= -1;

        // Collision with player
        if (player.x + player.w > e.x && player.x < e.x + e.w &&
            player.y + player.h > e.y && player.y < e.y + e.h) {

            if (player.velY > 0 && player.y + player.h - player.velY < e.y + 15) {
                // Stomp
                e.alive = false;
                player.velY = -10;
                score += 200;
                updateUI();
            } else {
                die();
            }
        }
    });

    // Coins
    coinList.forEach(c => {
        if (c.collected) return;
        if (player.x + player.w > c.x && player.x < c.x + 28 &&
            player.y + player.h > c.y && player.y < c.y + 28) {
            c.collected = true;
            coins++;
            score += 100;
            updateUI();
        }
    });

    // Flag / win
    if (player.x + player.w > flag.x && player.x < flag.x + flag.w &&
        player.y + player.h > flag.y) {
        win();
    }

    if (invincible > 0) invincible--;
}

// ===================== DRAW =====================
function drawCloud(x, y) {
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    ctx.beginPath();
    ctx.arc(x, y, 28, 0, Math.PI * 2);
    ctx.arc(x + 30, y - 8, 35, 0, Math.PI * 2);
    ctx.arc(x + 60, y, 28, 0, Math.PI * 2);
    ctx.fill();
}

function draw() {
    // Sky
    ctx.fillStyle = '#5C94FC';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Clouds (parallax)
    drawCloud(150 - cameraX * 0.3, 80);
    drawCloud(500 - cameraX * 0.3, 120);
    drawCloud(900 - cameraX * 0.3, 60);
    drawCloud(1400 - cameraX * 0.3, 100);

    ctx.save();
    ctx.translate(-cameraX, 0);

    // Ground
    ctx.fillStyle = '#E0A060';
    ctx.fillRect(0, 480, 3200, 80);
    ctx.fillStyle = '#5D9B3C';
    ctx.fillRect(0, 480, 3200, 18);

    // Platforms
    platforms.forEach(p => {
        if (p.y >= 480) return; // skip main ground
        ctx.fillStyle = '#C08040';
        ctx.fillRect(p.x, p.y, p.w, p.h);
        ctx.fillStyle = '#5D9B3C';
        ctx.fillRect(p.x, p.y, p.w, 8);
    });

    // Flag
    ctx.fillStyle = '#228B22';
    ctx.fillRect(flag.x, flag.y, 12, flag.h);
    ctx.fillStyle = '#FF0000';
    ctx.beginPath();
    ctx.moveTo(flag.x + 12, flag.y);
    ctx.lineTo(flag.x + 55, flag.y + 22);
    ctx.lineTo(flag.x + 12, flag.y + 44);
    ctx.fill();

    // Coins
    coinList.forEach(c => {
        if (c.collected) return;
        ctx.fillStyle = '#FFD700';
        ctx.beginPath();
        ctx.arc(c.x + 14, c.y + 14, 12, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#FFA500';
        ctx.beginPath();
        ctx.arc(c.x + 14, c.y + 14, 7, 0, Math.PI * 2);
        ctx.fill();
    });

    // Enemies
    enemies.forEach(e => {
        if (!e.alive) return;
        // Body
        ctx.fillStyle = '#8B4513';
        ctx.fillRect(e.x, e.y + 10, e.w, e.h - 10);
        // Head
        ctx.beginPath();
        ctx.arc(e.x + e.w / 2, e.y + 14, 18, 0, Math.PI * 2);
        ctx.fill();
        // Eyes
        ctx.fillStyle = '#FFF';
        ctx.fillRect(e.x + 10, e.y + 8, 8, 10);
        ctx.fillRect(e.x + 24, e.y + 8, 8, 10);
        ctx.fillStyle = '#000';
        ctx.fillRect(e.x + 13, e.y + 11, 4, 5);
        ctx.fillRect(e.x + 27, e.y + 11, 4, 5);
    });

    // Player
    if (invincible % 6 < 3 || invincible === 0) {
        if (playerImg.complete && playerImg.naturalWidth > 0) {
            ctx.save();
            if (player.facing === -1) {
                ctx.translate(player.x + player.w, player.y);
                ctx.scale(-1, 1);
                ctx.drawImage(playerImg, 0, 0, player.w, player.h);
            } else {
                ctx.drawImage(playerImg, player.x, player.y, player.w, player.h);
            }
            ctx.restore();
        } else {
            ctx.fillStyle = '#FF4500';
            ctx.fillRect(player.x, player.y, player.w, player.h);
        }
    }

    ctx.restore();
}

function loop() {
    update();
    draw();
    requestAnimationFrame(loop);
}

// Init enemies start positions
enemies.forEach(e => e.startX = e.x);
updateUI();
loop();
