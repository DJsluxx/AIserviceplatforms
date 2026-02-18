/* ═══════════════════════════════════════════════════════════
   Properties Genie — Main JavaScript
   ═══════════════════════════════════════════════════════════ */

document.addEventListener('DOMContentLoaded', () => {

    /* ── Mobile Nav Toggle ─────────────────────────────────── */
    const toggle = document.getElementById('navToggle');
    const menu   = document.getElementById('navMenu');
    if (toggle && menu) {
        toggle.addEventListener('click', () => {
            menu.classList.toggle('active');
            toggle.setAttribute('aria-expanded', menu.classList.contains('active'));
        });
        // Close on outside click
        document.addEventListener('click', (e) => {
            if (!toggle.contains(e.target) && !menu.contains(e.target)) {
                menu.classList.remove('active');
                toggle.setAttribute('aria-expanded', 'false');
            }
        });
    }

    /* ── Flash Auto-Dismiss ────────────────────────────────── */
    document.querySelectorAll('.flash').forEach(flash => {
        setTimeout(() => {
            flash.style.opacity = '0';
            flash.style.transform = 'translateY(-10px)';
            setTimeout(() => flash.remove(), 300);
        }, 5000);
    });
    document.querySelectorAll('.flash-close').forEach(btn => {
        btn.addEventListener('click', () => {
            const flash = btn.closest('.flash');
            flash.style.opacity = '0';
            flash.style.transform = 'translateY(-10px)';
            setTimeout(() => flash.remove(), 300);
        });
    });

    /* ── Copy to Clipboard ─────────────────────────────────── */
    document.querySelectorAll('[data-copy]').forEach(btn => {
        btn.addEventListener('click', () => {
            const target = document.getElementById(btn.dataset.copy);
            if (!target) return;
            const text = target.innerText || target.textContent;
            navigator.clipboard.writeText(text).then(() => showToast('Copied to clipboard!'));
        });
    });

    /* ── Copy Toast ────────────────────────────────────────── */
    function showToast(msg) {
        let toast = document.getElementById('copyToast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'copyToast';
            toast.className = 'copy-toast';
            document.body.appendChild(toast);
        }
        toast.innerHTML = `<i class="fas fa-check-circle"></i> ${msg}`;
        toast.classList.add('show');
        setTimeout(() => toast.classList.remove('show'), 2500);
    }

    /* ── Favorite Toggle ───────────────────────────────────── */
    document.querySelectorAll('.favorite-btn').forEach(btn => {
        btn.addEventListener('click', async () => {
            const url = btn.dataset.url;
            if (!url) return;
            try {
                const res = await fetch(url, { method: 'POST' });
                const data = await res.json();
                const icon = btn.querySelector('i');
                if (data.is_favorite) {
                    icon.classList.remove('far');
                    icon.classList.add('fas');
                    btn.classList.add('active');
                } else {
                    icon.classList.remove('fas');
                    icon.classList.add('far');
                    btn.classList.remove('active');
                }
            } catch (e) {
                console.error('Favorite toggle failed:', e);
            }
        });
    });

    /* ── Generator Form Loading State ──────────────────────── */
    const genForm = document.getElementById('genForm');
    if (genForm) {
        genForm.addEventListener('submit', () => {
            const btn = genForm.querySelector('button[type="submit"]');
            if (btn) {
                btn.disabled = true;
                btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Generating...';
            }
        });
    }

    /* ── Smooth Scroll for Anchor Links ────────────────────── */
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            const target = document.querySelector(anchor.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    /* ── Delete Confirmation ───────────────────────────────── */
    document.querySelectorAll('.delete-form').forEach(form => {
        form.addEventListener('submit', (e) => {
            if (!confirm('Delete this listing? This cannot be undone.')) {
                e.preventDefault();
            }
        });
    });

});
