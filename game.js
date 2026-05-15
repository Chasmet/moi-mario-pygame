const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

// Variables joueur
let player = { x: 100, y: 400, width: 50, height: 70, velY: 0, speed: 5, onGround: false };
let keys = {};

// Plateformes (comme tes screenshots)
const platforms = [
    {x:0, y:500, w:800, h:100}, // sol
    {x:150, y:420, w:130, h:20},
    {x:320, y:320, w:130, h:20},
    {x:500, y:380, w:110, h:20}
];

// Pipe
const pipe = {x:650, y:410, w:60, h:100};

// Image joueur (ta photo)
let playerImg = new Image();
playerImg.src = 'player.png'; // Mets ta photo ici

// Contrôles
window.addEventListener('keydown', e => keys[e.key] = true);
window.addEventListener('keyup', e => keys[e.key] = false);

function update() {
    // Mouvement horizontal
    if (keys['ArrowLeft'] || keys['q'] || keys['Q']) player.x -= player.speed;
    if (keys['ArrowRight'] || keys['d'] || keys['D']) player.x += player.speed;

    // Saut
    if ((keys[' '] || keys['ArrowUp']) && player.onGround) {
        player.velY = -17;
        player.onGround = false;
    }

    // Gravité
    player.velY += 0.85;
    player.y += player.velY;

    // Collisions
    player.onGround = false;
    for (let p of platforms) {
        if (player.x < p.x + p.w && player.x + player.width > p.x &&
            player.y < p.y + p.h && player.y + player.height > p.y && player.velY >= 0) {
            player.y = p.y - player.height;
            player.velY = 0;
            player.onGround = true;
        }
    }

    // Limites
    if (player.x < 0) player.x = 0;
    if (player.x + player.width > 800) player.x = 800 - player.width;
    if (player.y > 600) {
        player.y = 400; // reset
        player.velY = 0;
    }
}

function draw() {
    // Ciel
    ctx.fillStyle = '#5C94FC';
    ctx.fillRect(0, 0, 800, 600);

    // Plateformes
    ctx.fillStyle = '#C19A6B';
    for (let p of platforms) {
        ctx.fillRect(p.x, p.y, p.w, p.h);
    }

    // Pipe verte
    ctx.fillStyle = '#00AA00';
    ctx.fillRect(pipe.x, pipe.y, pipe.w, pipe.h);
    ctx.fillStyle = '#008800';
    ctx.fillRect(pipe.x-5, pipe.y-30, pipe.w+10, 35);

    // Dessin joueur (ta tête)
    if (playerImg.complete) {
        ctx.drawImage(playerImg, player.x, player.y, player.width, player.height);
    } else {
        // Fallback rectangle Naruto-like
        ctx.fillStyle = '#FF8800';
        ctx.fillRect(player.x, player.y, player.width, player.height);
        ctx.fillStyle = '#FFDD00';
        ctx.fillRect(player.x+10, player.y+10, 30, 25); // visage
    }
}

function gameLoop() {
    update();
    draw();
    requestAnimationFrame(gameLoop);
}

gameLoop();
