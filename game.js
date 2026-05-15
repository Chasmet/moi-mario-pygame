const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

const leftBtn = document.getElementById('leftBtn');
const rightBtn = document.getElementById('rightBtn');
const jumpBtn = document.getElementById('jumpBtn');
const restartBtn = document.getElementById('restartBtn');

let player = { x: 80, y: 300, w: 55, h: 75, velY: 0, speed: 6, jumping: false };
let keys = {};
let cameraX = 0;
let gravity = 0.85;
let score = 0;
let gameOver = false;

let playerImg = new Image();
playerImg.src = 'player.png';

let enemies = [
    { x: 650, y: 380, w: 48, h: 48, velX: -2.2 },
    { x: 1150, y: 380, w: 48, h: 48, velX: -2.2 }
];

let platforms = [
    { x: 0, y: 430, w: 2000, h: 70 },
    { x: 280, y: 340, w: 160, h: 25 },
    { x: 520, y: 260, w: 160, h: 25 },
    { x: 820, y: 340, w: 160, h: 25 },
    { x: 1250, y: 280, w: 160, h: 25 }
];

let pipe = { x: 1550, y: 370, w: 85, h: 110 };

let touchLeft = false;
let touchRight = false;

function resizeCanvas() {
    const ratio = 800 / 480;
    let width = window.innerWidth;
    let height = width / ratio;

    if (height > window.innerHeight) {
        height = window.innerHeight;
        width = height * ratio;
    }

    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
}

window.addEventListener('resize', resizeCanvas);
window.addEventListener('orientationchange', resizeCanvas);
resizeCanvas();

function bindHoldButton(button, onPress, onRelease) {
    const start = (e) => {
        e.preventDefault();
        button.classList.add('active');
        onPress();
    };

    const end = (e) => {
        e.preventDefault();
        button.classList.remove('active');
        onRelease();
    };

    ['touchstart', 'mousedown'].forEach(evt => button.addEventListener(evt, start, { passive: false }));
    ['touchend', 'touchcancel', 'mouseup', 'mouseleave'].forEach(evt => button.addEventListener(evt, end, { passive: false }));
}

bindHoldButton(leftBtn, () => touchLeft = true, () => touchLeft = false);
bindHoldButton(rightBtn, () => touchRight = true, () => touchRight = false);
bindHoldButton(
    jumpBtn,
    () => {
        if (!player.jumping && !gameOver) {
            player.velY = -19;
            player.jumping = true;
        }
    },
    () => {}
);

restartBtn.addEventListener('click', () => location.reload());
restartBtn.addEventListener('touchstart', (e) => {
    e.preventDefault();
    location.reload();
}, { passive: false });

document.addEventListener('keydown', e => {
    keys[e.key.toLowerCase()] = true;

    if (e.key.toLowerCase() === 'r' && gameOver) {
        location.reload();
    }
});

document.addEventListener('keyup', e => {
    keys[e.key.toLowerCase()] = false;
});

function update() {
    if (gameOver) return;

    if (keys['arrowleft'] || keys['q'] || touchLeft) player.x -= player.speed;
    if (keys['arrowright'] || keys['d'] || touchRight) player.x += player.speed;

    if ((keys[' '] || keys['arrowup']) && !player.jumping) {
        player.velY = -19;
        player.jumping = true;
    }

    player.velY += gravity;
    player.y += player.velY;

    player.jumping = true;
    for (const p of platforms) {
        if (
            player.x + player.w > p.x &&
            player.x < p.x + p.w &&
            player.y + player.h > p.y &&
            player.y + player.h - player.velY <= p.y + 10
        ) {
            player.y = p.y - player.h;
            player.velY = 0;
            player.jumping = false;
        }
    }

    if (player.y > 600) gameOver = true;

    if (player.x < cameraX + 30) player.x = cameraX + 30;
    if (player.x > cameraX + 450) cameraX = player.x - 450;

    enemies.forEach(enemy => {
        if (enemy.x < 0) return;

        enemy.x += enemy.velX;
        if (enemy.x < 300) enemy.velX = 2.5;
        if (enemy.x > 1700) enemy.velX = -2.5;

        if (
            player.x + player.w > enemy.x &&
            player.x < enemy.x + enemy.w &&
            player.y + player.h > enemy.y &&
            player.y < enemy.y + enemy.h
        ) {
            if (player.velY > 0 && player.y + player.h - player.velY < enemy.y + 10) {
                enemy.x = -100;
                score += 200;
                player.velY = -10;
            } else {
                gameOver = true;
            }
        }
    });

    score += 1;

    if (gameOver) {
        restartBtn.style.display = 'block';
    }
}

function draw() {
    ctx.fillStyle = '#5C94FC';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.save();
    ctx.translate(-cameraX, 0);

    ctx.fillStyle = '#E0B070';
    ctx.fillRect(0, 430, 2500, 100);

    ctx.fillStyle = '#E8B76B';
    platforms.forEach(p => ctx.fillRect(p.x, p.y, p.w, p.h));

    ctx.fillStyle = '#00A000';
    ctx.fillRect(pipe.x, pipe.y, pipe.w, pipe.h);

    if (playerImg.complete && playerImg.naturalWidth > 0) {
        ctx.drawImage(playerImg, player.x, player.y, player.w, player.h);
    } else {
        ctx.fillStyle = '#FF4500';
        ctx.fillRect(player.x, player.y, player.w, player.h);
    }

    enemies.forEach(enemy => {
        if (enemy.x < 0) return;

        ctx.fillStyle = '#8B4513';
        ctx.fillRect(enemy.x, enemy.y, enemy.w, enemy.h);

        ctx.fillStyle = '#000';
        ctx.fillRect(enemy.x + 10, enemy.y + 15, 12, 12);
        ctx.fillRect(enemy.x + 28, enemy.y + 15, 12, 12);
    });

    ctx.restore();

    ctx.fillStyle = '#FFF';
    ctx.font = 'bold 22px Arial';
    ctx.fillText('Score: ' + Math.floor(score / 8), 30, 45);

    if (gameOver) {
        ctx.fillStyle = 'rgba(0,0,0,0.7)';
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        ctx.fillStyle = '#FF0000';
        ctx.font = 'bold 48px Arial';
        ctx.fillText('GAME OVER', 220, 220);

        ctx.font = 'bold 24px Arial';
        ctx.fillStyle = '#FFF';
        ctx.fillText('Touchez RESTART pour rejouer', 180, 280);
    }
}

function loop() {
    update();
    draw();
    requestAnimationFrame(loop);
}

loop();