let menuOpen = false;
let businesses = {}; // Central for all businesses
let currentTab = 'owned'; // 'owned' = my companies, 'available' = available for buy
const lastRefreshTimes = {}; 

window.addEventListener('message', function (event) {
    const data = event.data;

    switch (data.action) {
        case "openMenu":
            if (menuOpen) return;
            menuOpen = true;

            const main = document.getElementById("main");
            main.style.transition = '';
            main.style.opacity = '0';
            main.style.display = "flex";

            setTimeout(() => {
                main.style.transition = 'opacity 0.3s ease';
                main.style.opacity = '1';
            }, 50);

            renderBusinesses(data.businesses || {});
            break;

        case "updateBusinesses":
            renderBusinesses(data.businesses || {});
            break;

        case "updateBusiness":
            businesses[data.key] = data.data;

            const container = document.getElementById("businesses");
            const cards = container.getElementsByClassName("business-card");
            let exists = false;
            for (const card of cards) {
                const title = card.querySelector("h3");
                if (title && title.textContent === data.key) {
                    exists = true;
                    break;
                }
            }

            if (exists) {
                updateBusinessDisplay(data.key);
            } else {
                renderBusinesses(businesses);
            }
            break;

        case "closeMenu":
            if (!menuOpen) return;

            const mainEl = document.getElementById("main");
            mainEl.style.transition = 'opacity 0.3s ease';
            mainEl.style.opacity = '0';

            setTimeout(() => {
                mainEl.style.display = "none";
                mainEl.style.transition = '';
                mainEl.style.opacity = '1';
                menuOpen = false;
            }, 300);
            break;
    }
});



function renderBusinesses(data) {
    businesses = data; 

    
    const hasOwned = Object.values(businesses).some(biz => biz.level > 0);

   
    if (currentTab === 'owned' && !hasOwned) {
        currentTab = 'available';
        updateTabUI();
    }

    const container = document.getElementById("businesses");
    container.innerHTML = "";

    for (const [key, biz] of Object.entries(businesses)) {
        
        if (currentTab === 'owned' && (!biz.level || biz.level === 0)) {
            
            continue;
        }
    

        const card = buildBusinessCard(key, biz);
        container.appendChild(card);
    }
}



/**
 * Update de specifieke kaart van een bedrijf, bijvoorbeeld na upgrade of balanswijziging
 */
function updateBusinessDisplay(key) {
    const biz = businesses[key];
    if (!biz) return;

    const container = document.getElementById("businesses");
    const cards = container.getElementsByClassName("business-card");

    for (const card of cards) {
        if (card.dataset.key === key) {
            const updatedCard = buildBusinessCard(key, biz);
            container.replaceChild(updatedCard, card);
            return;
        }
    }
}


/**
 * Bouwt een enkele bedrijfskaart
 */
function buildBusinessCard(key, biz) {
    const now = Math.floor(Date.now() / 1000);
    const isOwned = biz.level > 0;
    const isAvailableTab = currentTab === 'available';

    const card = document.createElement('div');
    card.className = 'business-card';
    card.dataset.key = key;

    
    if (isAvailableTab && isOwned) {
        const badge = document.createElement('div');
        badge.className = 'owned-badge';
        badge.textContent = 'Bought';
        card.appendChild(badge);
    }

    
    const leftCol = document.createElement('div');
    leftCol.className = 'left-col';

    if (biz.image) {
        const img = document.createElement('img');
        img.className = 'business-image';
        img.src = `./images/${biz.image}`;
        img.alt = biz.label || key;
        leftCol.appendChild(img);
    }

    const title = document.createElement('h3');
    title.textContent = biz.label || key;
    leftCol.appendChild(title);

   
    const rightCol = document.createElement('div');
    rightCol.className = 'right-col';

    if (!isAvailableTab && isOwned) {
        const balance = document.createElement('p');
        balance.className = 'biz-balance';
        balance.innerHTML = `Savings: <strong>$${biz.balance}</strong>`;
        rightCol.appendChild(balance);

        // Add level display in bottom right
        const levelWrap = document.createElement('div');
        levelWrap.className = 'level-wrap';
        
        let levelText = `Level: <strong>${biz.level}</strong>`;
        if (biz.upgrade_ready_at && biz.upgrade_ready_at > now) {
            const targetLevel = biz.level + 1;
            levelText += ` <em style="font-weight: normal; font-style: italic; color: #ffa500;">(upgrading to level ${targetLevel})</em>`;
        }
        
        levelWrap.innerHTML = levelText;
        rightCol.appendChild(levelWrap);

        if (biz.maxLevel && biz.level >= biz.maxLevel) {
            const maxedText = document.createElement('p');
            maxedText.style.color = 'goldenrod';
            maxedText.style.fontWeight = 'bold';
            maxedText.textContent = "MAX LEVEL REACHED!";
            rightCol.appendChild(maxedText);
        } else {
            const isUpgrading = biz.upgrade_ready_at && biz.upgrade_ready_at > now;

            // 🔁 ProgressBar als upgrading
            if (isUpgrading) {
                const remaining = biz.upgrade_ready_at - now;
                const totalTime = biz.upgrade_duration || 43200;
                const percent = Math.max(0, 100 - (remaining / totalTime) * 100);

                const upgradeContainer = document.createElement('div');
                upgradeContainer.className = 'upgrade-container';

                const upgradeLabel = document.createElement('div');
                upgradeLabel.className = 'upgrade-label';
                upgradeLabel.textContent = `${formatTime(remaining)} remaining`;

                const progressbar = document.createElement('div');
                progressbar.className = 'upgrade-progressbar';

                const progressFill = document.createElement('div');
                progressFill.className = 'upgrade-progressbar-fill';
                progressFill.style.width = `${Math.round(percent)}%`;

                progressbar.appendChild(progressFill);
                upgradeContainer.appendChild(upgradeLabel);
                upgradeContainer.appendChild(progressbar);
                rightCol.appendChild(upgradeContainer);
            }

            // 🔘 Upgrade knop
            const upgradeAction = document.createElement('div');
            upgradeAction.className = 'upgrade-action';

            const upgradeBtn = document.createElement('button');
            upgradeBtn.className = 'btn-upgrade';
            upgradeBtn.disabled = isUpgrading;
            upgradeBtn.textContent = isUpgrading ? 'Busy upgrading...' : `Upgrade ($${biz.upgradeCost})`;

            upgradeBtn.onclick = () => {
                if (!upgradeBtn.disabled) upgradeBusiness(key);
            };

            upgradeAction.appendChild(upgradeBtn);
            rightCol.appendChild(upgradeAction);
        }
    }

    
    if (isAvailableTab && !isOwned) {
        const description = document.createElement('p');
        description.className = 'biz-description';
        description.textContent = biz.description || "Geen beschrijving beschikbaar.";

        const buyBtn = document.createElement('button');
        buyBtn.className = 'btn-buy';
        buyBtn.textContent = `Buy for $${biz.price}`;
        buyBtn.onclick = () => buyBusiness(key);

        const buyWrapper = document.createElement('div');
        buyWrapper.className = 'buy-wrapper';
        buyWrapper.appendChild(description);
        buyWrapper.appendChild(buyBtn);

        rightCol.appendChild(buyWrapper);
    } else if (isAvailableTab) {
        const description = document.createElement('p');
        description.className = 'biz-description';
        description.textContent = biz.description || "Geen beschrijving beschikbaar.";
        rightCol.appendChild(description);
    }

    card.appendChild(leftCol);
    card.appendChild(rightCol);
    return card;
}

function updateBusinessCard(key, biz) {
    const card = document.querySelector(`.business-card[data-key="${key}"]`);
    if (!card) return;

    const now = Math.floor(Date.now() / 1000);
    const isUpgrading = biz.upgrade_ready_at && biz.upgrade_ready_at > now;

    const progressFill = card.querySelector('.upgrade-progressbar-fill');
    const upgradeLabel = card.querySelector('.upgrade-label');
    const upgradeBtn = card.querySelector('.btn-upgrade');
    const levelTextEl = card.querySelector('.level-wrap');
    const balanceEl = card.querySelector('.biz-balance');
    const dots = card.querySelectorAll('.level-dot');

    // ⏳ Update progressbar & label bij upgrade
    if (isUpgrading) {
        const remaining = biz.upgrade_ready_at - now;
        const totalTime = biz.upgrade_duration || 43200;
        const percent = Math.min(100, Math.max(0, 100 - (remaining / totalTime) * 100));

        if (progressFill) progressFill.style.width = `${Math.round(percent)}%`;
        if (upgradeLabel) upgradeLabel.textContent = `${formatTime(remaining)} untill the upgrade is finished`;

        // Zet knop uit
        if (upgradeBtn) {
            upgradeBtn.disabled = true;
            upgradeBtn.textContent = 'Upgrading';
        }

        // Plan automatische refresh wanneer upgrade klaar is
        const timeoutMs = (biz.upgrade_ready_at * 1000) - Date.now();

        // Clear oude timeout indien aanwezig
        if (biz._refreshTimeout) {
            clearTimeout(biz._refreshTimeout);
        }

        biz._refreshTimeout = setTimeout(() => {
            fetch(`https://${GetParentResourceName()}/refreshBusiness`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ bizKey: key })
            });
        }, timeoutMs);

    } else {
        // Upgrade is klaar of niet bezig, reset progressbar & label
        if (progressFill) progressFill.style.width = '0%';
        if (upgradeLabel) upgradeLabel.textContent = '';

        // Zet knop aan met correcte prijs
        if (upgradeBtn) {
            upgradeBtn.disabled = false;
            upgradeBtn.textContent = `Upgrading ($${biz.upgradeCost})`;
        }

        // Clear eventuele timeout
        if (biz._refreshTimeout) {
            clearTimeout(biz._refreshTimeout);
            biz._refreshTimeout = null;
        }
    }

    // 🔢 Update level tekst
    if (levelTextEl && typeof biz.level === 'number') {
        let levelText = `Level: <strong>${biz.level}</strong>`;
        if (isUpgrading) {
            levelText += ` <em style="font-weight: normal; font-style: italic; color: #ffa500;">(Upgrade to ${biz.level + 1} busy)</em>`;
        }
        levelTextEl.innerHTML = levelText;
    }

    // 💰 Update balance
    if (balanceEl) {
        balanceEl.innerHTML = `Savings: <strong>$${biz.balance}</strong>`;
    }

    // 🔵 Update level-indicator dots
    if (dots.length && typeof biz.displayLevel === 'number') {
        dots.forEach((dot, idx) => {
            dot.classList.toggle('active', idx < biz.displayLevel);
        });
    }
}




function formatTime(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;

    const pad = (n) => n.toString().padStart(2, '0');

    if (h > 0) {
        return `${h}u ${pad(m)}m`;
    } else if (m > 0) {
        return `${m}m ${pad(s)}s`;
    } else {
        return `${s}s`;
    }
}



function collectIncome() {
    fetch(`https://${GetParentResourceName()}/collectIncome`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{}'
    }).catch(() => {});
}

function buyBusiness(name) {
    const container = document.getElementById("businesses");
    if (!container) return;

    const cards = container.getElementsByClassName("business-card");
    for (const card of cards) {
        if (card.dataset.key === name) {
            const buyBtn = card.querySelector(".btn-buy");
            if (buyBtn) {
                buyBtn.disabled = true;
                buyBtn.textContent = "Buying..";
            }
        }
    }

    fetch(`https://${GetParentResourceName()}/buyBusiness`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
    }).catch(() => {});
}


function upgradeBusiness(name) {
    const container = document.getElementById("businesses");
    if (!container) return;

    const cards = container.getElementsByClassName("business-card");
    for (const card of cards) {
        if (card.dataset.key === name) {
            const upgradeBtn = card.querySelector("button.btn-upgrade");
            if (upgradeBtn) {
                upgradeBtn.disabled = true;
                upgradeBtn.textContent = "Upgrading...";
            }
            break; // kaart gevonden, stoppen met zoeken
        }
    }

    // Stuur request naar server
    fetch(`https://${GetParentResourceName()}/upgradeBusiness`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name })
    }).catch(() => {});
}



function closeMenu() {
    console.log("Closing menu...");

    // Opruimen van alle timers die in updateBusinessCard zijn gezet
    if (typeof businesses === 'object') {
        for (const key in businesses) {
            if (businesses[key]._refreshTimeout) {
                clearTimeout(businesses[key]._refreshTimeout);
                businesses[key]._refreshTimeout = null;
            }
        }
    }

    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{}'
    }).catch(() => {});

    // NIET direct zelf het menu verbergen! Dat doet de server via de 'closeMenu' actie.
}




setInterval(() => {
    if (!menuOpen) return;

    const now = Math.floor(Date.now() / 1000);
    const container = document.getElementById("businesses");
    if (!container) return;

    const cards = container.getElementsByClassName("business-card");

    for (const card of cards) {
        const key = card.dataset.key;
        const biz = businesses[key];
        if (!biz) continue;

        if (biz.upgrade_ready_at && biz.upgrade_ready_at > now) {
            const remaining = biz.upgrade_ready_at - now;
            const totalTime = biz.upgrade_duration || 43200;
            const percent = Math.max(0, 100 - (remaining / totalTime) * 100);

            const label = card.querySelector(".upgrade-label");
            const fill = card.querySelector(".upgrade-progressbar-fill");
            const upgradeBtn = card.querySelector(".btn-upgrade");

            if (label) label.textContent = `${formatTime(remaining)} untill the upgrade is finished.`;
            if (fill) fill.style.width = `${percent}%`;
            if (upgradeBtn) upgradeBtn.disabled = true;

        } else if (biz.upgrade_ready_at && biz.upgrade_ready_at <= now) {
            const label = card.querySelector(".upgrade-label");
            const fill = card.querySelector(".upgrade-progressbar-fill");
            const upgradeBtn = card.querySelector(".btn-upgrade");

            if (label) label.textContent = "Upgrade finished!";
            if (fill) fill.style.width = "100%";
            if (upgradeBtn) upgradeBtn.disabled = false;

            // Check throttling: alleen als laatste refresh > 30 sec geleden
            const lastRefresh = lastRefreshTimes[key] || 0;
            if (now - lastRefresh > 30) {
                fetch(`https://${GetParentResourceName()}/refreshBusiness`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ bizKey: key })
                });
                lastRefreshTimes[key] = now;
            }
        }
    }
}, 1000);



document.getElementById('tab-owned').addEventListener('click', () => {
    currentTab = 'owned';
    renderBusinesses(businesses);
    updateTabUI();
});

document.getElementById('tab-available').addEventListener('click', () => {
    currentTab = 'available';
    renderBusinesses(businesses);
    updateTabUI();
});

function updateTabUI() {
    const tabOwned = document.getElementById('tab-owned');
    const tabAvailable = document.getElementById('tab-available');

    if (currentTab === 'owned') {
        tabOwned.classList.add('active');
        tabAvailable.classList.remove('active');
    } else {
        tabOwned.classList.remove('active');
        tabAvailable.classList.add('active');
    }
}

document.getElementById('collectIncomeBtn').addEventListener('click', () => {
    collectIncome();
});

document.getElementById('closeBtn').addEventListener('click', () => {
    closeMenu();
});

// Init UI status bij laden
updateTabUI();

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'Esc') {
        if (menuOpen) {
            closeMenu();
        }
    }
});
