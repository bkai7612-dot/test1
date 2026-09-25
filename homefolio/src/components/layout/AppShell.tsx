import { Building2, FileText, House, LayoutGrid, LogOut, Search, Wrench } from 'lucide-react';
import { Suspense } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';
import { useProperties } from '@/context/PropertyContext';
import { cn } from '@/lib/cn';
import { Spinner } from '../ui/States';
import { Logo } from './Logo';
import { NAV_GROUPS, SETTINGS_ITEM, type NavItem } from './nav';
import { PropertySwitcher } from './PropertySwitcher';

function SidebarLink({ item }: { item: NavItem }) {
  const Icon = item.icon;
  return (
    <NavLink
      to={item.to}
      end={item.to === '/'}
      className={({ isActive }) =>
        cn(
          'flex min-h-9 items-center gap-3 rounded-xl px-3 text-sm font-medium transition-colors',
          isActive
            ? 'bg-brand-50 text-brand-800 dark:bg-brand-900/40 dark:text-brand-200'
            : 'text-muted hover:bg-surface-muted hover:text-ink',
        )
      }
    >
      <Icon className="size-[18px] shrink-0" aria-hidden />
      {item.label}
    </NavLink>
  );
}

function Sidebar() {
  const { signOut } = useAuth();
  return (
    <aside className="border-line bg-surface fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r lg:flex">
      <div className="px-5 pt-4 pb-3">
        <Logo />
      </div>
      <div className="px-3 pb-3">
        <PropertySwitcher />
      </div>
      <nav aria-label="Main" className="flex-1 space-y-3 overflow-y-auto px-3 pb-3">
        {NAV_GROUPS.map((group, i) => (
          <div key={i}>
            {group.label && (
              <p className="text-muted/80 mb-1 px-3 text-xs font-semibold tracking-wide uppercase">{group.label}</p>
            )}
            <div className="space-y-0.5">
              {group.items.map((item) => (
                <SidebarLink key={item.to} item={item} />
              ))}
            </div>
          </div>
        ))}
      </nav>
      <div className="border-line space-y-0.5 border-t p-2">
        <SidebarLink item={SETTINGS_ITEM} />
        <button
          type="button"
          onClick={signOut}
          className="text-muted hover:bg-surface-muted hover:text-ink flex min-h-9 w-full items-center gap-3 rounded-xl px-3 text-sm font-medium transition-colors"
        >
          <LogOut className="size-[18px]" aria-hidden />
          Log out
        </button>
      </div>
    </aside>
  );
}

const BOTTOM_ITEMS: NavItem[] = [
  { to: '/', label: 'Home', icon: House },
  { to: '/properties', label: 'Properties', icon: Building2 },
  { to: '/maintenance', label: 'Maintenance', icon: Wrench },
  { to: '/documents', label: 'Documents', icon: FileText },
  { to: '/more', label: 'More', icon: LayoutGrid },
];

const PRIMARY_PATHS = ['/', '/properties', '/maintenance', '/documents'];

function BottomNav() {
  const { pathname } = useLocation();
  // Everything that isn't one of the four primary tabs lives under "More".
  const moreActive = !PRIMARY_PATHS.some((p) => (p === '/' ? pathname === '/' : pathname.startsWith(p)));
  return (
    <nav
      aria-label="Main"
      className="pb-safe border-line bg-surface/95 fixed inset-x-0 bottom-0 z-30 border-t backdrop-blur lg:hidden"
    >
      <ul className="mx-auto grid max-w-lg grid-cols-5">
        {BOTTOM_ITEMS.map((item) => {
          const Icon = item.icon;
          return (
            <li key={item.to}>
              <NavLink
                to={item.to}
                end={item.to === '/'}
                className={({ isActive }) => {
                  const on = item.to === '/more' ? moreActive : isActive;
                  return cn(
                    'flex min-h-16 flex-col items-center justify-center gap-1 text-[11px] font-medium transition-colors',
                    on ? 'text-brand-fg' : 'text-muted hover:text-ink',
                  );
                }}
              >
                <Icon className="size-6" aria-hidden />
                {item.label}
              </NavLink>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

function TopBar() {
  const { active } = useProperties();
  return (
    <header className="border-line bg-canvas/90 sticky top-0 z-20 border-b backdrop-blur">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-3 px-4 sm:px-6 lg:h-16 lg:px-8">
        <div className="flex min-w-0 items-center gap-2 lg:hidden">
          <Logo iconOnly />
          {active && <PropertySwitcher compact />}
        </div>
        <Link
          to="/search"
          className="border-line bg-surface text-muted hover:text-ink ml-auto flex min-h-10 items-center gap-2 rounded-xl border px-3 text-sm transition-colors lg:ml-0 lg:w-80"
          aria-label="Search your home"
        >
          <Search className="size-4" aria-hidden />
          <span className="hidden sm:inline">Search your home…</span>
        </Link>
      </div>
    </header>
  );
}

export function AppShell() {
  return (
    <div className="min-h-dvh">
      <a
        href="#main"
        className="bg-brand-600 sr-only z-50 rounded-lg px-4 py-2 text-white focus:not-sr-only focus:fixed focus:top-2 focus:left-2"
      >
        Skip to content
      </a>
      <Sidebar />
      <div className="lg:pl-64">
        <TopBar />
        <main id="main" className="mx-auto max-w-6xl px-4 pt-5 pb-28 sm:px-6 lg:px-8 lg:pt-8 lg:pb-12">
          <Suspense fallback={<Spinner />}>
            <Outlet />
          </Suspense>
        </main>
      </div>
      <BottomNav />
    </div>
  );
}
