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

const GRAVITY = 0.72;
const JUMP_FORCE = -16.8;
const MOVE_SPEED = 5.4;
const FRICTION = 0.8;

let player = { x: 80, y: 200, w: 50, h: 76, velX: 0, velY: 0, onGround: false, facing: 1 };
let cameraX = 0, score = 0, coins = 0, lives = 3, gameState = 'play', invincible = 0;

const playerImg = new Image();
playerImg.src = 'player.png';

const platforms = [
    { x: 0, y: 480, w: 3400, h: 80 },
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
    { x: 2850, y: 360, w: 180, h: 22 },
    { x: 3100, y: 300, w: 150, h: 22 }
];

let enemies = [
    { x: 380, y: 432, w: 44, h: 44, velX: -1.9, alive: true },
    { x: 720, y: 432, w: 44, h: 44, velX: 1.7, alive: true },
    { x: 980, y: 432, w: 44, h: 44, velX: -2.1, alive: true },
    { x: 1420, y: 432, w: 44, h: 44, velX: 1.8, alive: true },
    { x: 1880, y: 432, w: 44, h: 44, velX: -1.6, alive: true },
    { x: 2380, y: 432, w: 44, h: 44, velX: 2.0, alive: true },
    { x: 2750, y: 432, w: 44, h: 44, velX: -1.7, alive: true },
    { x: 3050, y: 432, w: 44, h: 44, velX: 1.9, alive: true }
];

let coinList = [
    {x:260,y:340},{x:460,y:260},{x:680,y:340},{x:880,y:220},
    {x:1120,y:300},{x:1360,y:210},{x:1620,y:320},{x:1860,y:240},
    {x:2100,y:160},{x:2360,y:280},{x:2650,y:200},{x:2900,y:320},
    {x:3150,y:260}
].map(c => ({...c, collected: false}));

const flag = { x: 3280, y: 300, w: 20, h: 180 };

let keys = {}, touchLeft = false, touchRight = false;

function bindHold(btn, on, off) {
    const start = e => { e.preventDefault(); btn.classList.add('active'); on(); };
    const end = e => { e.preventDefault(); btn.classList.remove('active'); off(); };
    ['touchstart','mousedown'].forEach(ev => btn.addEventListener(ev, start, {passive:false}));
    ['touchend','touchcancel','mouseup','mouseleave'].forEach(ev => btn.addEventListener(ev, end, {passive:false}));
}
bindHold(leftBtn, () => touchLeft = true, () => touchLeft = false);
bindHold(rightBtn, () => touchRight = true, () => touchRight = false);
bindHold(jumpBtn, () => { if (player.onGround && gameState === 'play') { player.velY = JUMP_FORCE; player.onGround = false; } }, () => {});

restartBtn.onclick = resetGame;
restartBtn.addEventListener('touchstart', e => { e.preventDefault(); resetGame(); }, {passive:false});

document.addEventListener('keydown', e => {
    keys[e.key.toLowerCase()] = true;
    if ((e.key === ' ' || e.key === 'ArrowUp') && player.onGround && gameState === 'play') {
        player.velY = JUMP_FORCE; player.onGround = false;
    }
    if (e.key.toLowerCase() === 'r' && gameState !== 'play') resetGame();
});
document.addEventListener('keyup', e => keys[e.key.toLowerCase()] = false);

function resize() {
    const ratio = 960/540;
    let w = window.innerWidth, h = w / ratio;
    if (h > window.innerHeight) { h = window.innerHeight; w = h * ratio; }
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
}
window.addEventListener('resize', resize);
window.addEventListener('orientationchange', resize);
resize();

function resetGame() {
    player = { x: 80, y: 200, w: 50, h: 76, velX: 0, velY: 0, onGround: false, facing: 1 };
    cameraX = 0; score = 0; coins = 0; lives = 3; invincible = 0; gameState = 'play';
    overlay.style.display = 'none';
    enemies.forEach(e => { e.alive = true; e.x = e.startX; });
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
        player.x = Math.max(80, cameraX + 120);
        player.y = 200;
        player.velY = 0;
        invincible = 100;
    }
}

function win() {
    gameState = 'win';
    score += 1500 + coins * 50;
    updateUI();
    overlayTitle.textContent = 'VICTOIRE !';
    overlayMsg.textContent = 'CHK NOIR a gagné !  Score : ' + score;
    overlay.style.display = 'flex';
}

function update() {
    if (gameState !== 'play') return;

    let moving = false;
    if (keys['arrowleft'] || keys['q'] || keys['a'] || touchLeft) { player.velX = -MOVE_SPEED; player.facing = -1; moving = true; }
    if (keys['arrowright'] || keys['d'] || touchRight) { player.velX = MOVE_SPEED; player.facing = 1; moving = true; }
    if (!moving) player.velX *= FRICTION;
    if (Math.abs(player.velX) < 0.25) player.velX = 0;
    player.x += player.velX;

    player.velY += GRAVITY;
    player.y += player.velY;

    player.onGround = false;
    for (const p of platforms) {
        if (player.x + player.w > p.x && player.x < p.x + p.w) {
            if (player.velY >= 0 && player.y + player.h > p.y && player.y + player.h - player.velY <= p.y + 14) {
                player.y = p.y - player.h;
                player.velY = 0;
                player.onGround = true;
            }
        }
    }

    if (player.y > 620) die();

    if (player.x > cameraX + 400) cameraX = player.x - 400;
    if (player.x < cameraX + 140) cameraX = Math.max(0, player.x - 140);
    cameraX = Math.max(0, Math.min(cameraX, 3400 - 960));

    enemies.forEach(e => {
        if (!e.alive) return;
        e.x += e.velX;
        if (e.x < 40 || e.x > 3300) e.velX *= -1;

        if (player.x + player.w > e.x && player.x < e.x + e.w && player.y + player.h > e.y && player.y < e.y + e.h) {
            if (player.velY > 0 && player.y + player.h - player.velY < e.y + 16) {
                e.alive = false;
                player.velY = -11;
                score += 250;
                updateUI();
            } else die();
        }
    });

    coinList.forEach(c => {
        if (c.collected) return;
        if (player.x + player.w > c.x && player.x < c.x + 26 && player.y + player.h > c.y && player.y < c.y + 26) {
            c.collected = true;
            coins++;
            score += 100;
            updateUI();
        }
    });

    if (player.x + player.w > flag.x && player.x < flag.x + flag.w && player.y + player.h > flag.y) win();

    if (invincible > 0) invincible--;
}

function drawCloud(x, y) {
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.beginPath();
    ctx.arc(x, y, 26, 0, Math.PI*2);
    ctx.arc(x+28, y-6, 32, 0, Math.PI*2);
    ctx.arc(x+56, y, 26, 0, Math.PI*2);
    ctx.fill();
}

function draw() {
    // Sky gradient
    const grd = ctx.createLinearGradient(0, 0, 0, 540);
    grd.addColorStop(0, '#1a6fb5');
    grd.addColorStop(1, '#5C94FC');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, 960, 540);

    drawCloud(120 - cameraX*0.25, 70);
    drawCloud(480 - cameraX*0.25, 110);
    drawCloud(860 - cameraX*0.25, 55);
    drawCloud(1300 - cameraX*0.25, 90);

    ctx.save();
    ctx.translate(-cameraX, 0);

    // Ground
    ctx.fillStyle = '#C48A3A';
    ctx.fillRect(0, 480, 3400, 80);
    ctx.fillStyle = '#4CAF50';
    ctx.fillRect(0, 480, 3400, 16);

    // Platforms
    platforms.forEach(p => {
        if (p.y >= 480) return;
        ctx.fillStyle = '#A86B2D';
        ctx.fillRect(p.x, p.y, p.w, p.h);
        ctx.fillStyle = '#66BB6A';
        ctx.fillRect(p.x, p.y, p.w, 7);
    });

    // Flag
    ctx.fillStyle = '#1B5E20';
    ctx.fillRect(flag.x, flag.y, 10, flag.h);
    ctx.fillStyle = '#FF1744';
    ctx.beginPath();
    ctx.moveTo(flag.x+10, flag.y);
    ctx.lineTo(flag.x+52, flag.y+20);
    ctx.lineTo(flag.x+10, flag.y+40);
    ctx.fill();

    // Coins
    coinList.forEach(c => {
        if (c.collected) return;
        ctx.fillStyle = '#FFD600';
        ctx.beginPath();
        ctx.arc(c.x+13, c.y+13, 12, 0, Math.PI*2);
        ctx.fill();
        ctx.fillStyle = '#FF8F00';
        ctx.beginPath();
        ctx.arc(c.x+13, c.y+13, 6, 0, Math.PI*2);
        ctx.fill();
    });

    // Enemies (simple style)
    enemies.forEach(e => {
        if (!e.alive) return;
        // body
        ctx.fillStyle = '#5D4037';
        ctx.beginPath();
        ctx.ellipse(e.x + e.w/2, e.y + e.h/2 + 4, e.w/2, e.h/2 - 2, 0, 0, Math.PI*2);
        ctx.fill();
        // eyes
        ctx.fillStyle = '#FFF';
        ctx.fillRect(e.x + 10, e.y + 12, 9, 11);
        ctx.fillRect(e.x + 26, e.y + 12, 9, 11);
        ctx.fillStyle = '#000';
        ctx.fillRect(e.x + 13, e.y + 15, 4, 5);
        ctx.fillRect(e.x + 29, e.y + 15, 4, 5);
    });

    // Player (CHK NOIR)
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
            // fallback CHK
            ctx.fillStyle = '#00A8FF';
            ctx.fillRect(player.x, player.y, player.w, player.h);
            ctx.fillStyle = '#fff';
            ctx.font = 'bold 14px Arial';
            ctx.fillText('CHK', player.x + 8, player.y + 42);
        }
    }

    ctx.restore();
}

function loop() {
    update();
    draw();
    requestAnimationFrame(loop);
}

enemies.forEach(e => e.startX = e.x);
updateUI();
loop();
