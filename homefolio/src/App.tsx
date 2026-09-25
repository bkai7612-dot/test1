import { lazy, Suspense, type ReactNode } from 'react';
import { BrowserRouter, HashRouter, MemoryRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { AppShell } from './components/layout/AppShell';
import { NativeBridge } from './components/NativeBridge';
import { TourProvider } from './components/help/Tour';
import { Spinner } from './components/ui/States';
import { AuthProvider, useAuth } from './context/AuthContext';
import { CategoriesProvider } from './context/CategoriesContext';
import { PropertyProvider } from './context/PropertyContext';
import { ToastProvider } from './context/ToastContext';
import { isSupabaseConfigured } from '@/lib/supabase';
import { RequireProperty } from './pages/RequireProperty';
import { SetupRequired } from './pages/SetupRequired';

const Login = lazy(() => import('./pages/auth/Login'));
const Register = lazy(() => import('./pages/auth/Register'));
const ForgotPassword = lazy(() => import('./pages/auth/ForgotPassword'));
const ResetPassword = lazy(() => import('./pages/auth/ResetPassword'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Properties = lazy(() => import('./pages/Properties'));
const PropertyDetail = lazy(() => import('./pages/PropertyDetail'));
const Rooms = lazy(() => import('./pages/Rooms'));
const RoomDetail = lazy(() => import('./pages/RoomDetail'));
const ItemsList = lazy(() => import('./pages/items/ItemsList'));
const ItemDetail = lazy(() => import('./pages/items/ItemDetail'));
const Warranties = lazy(() => import('./pages/Warranties'));
const Maintenance = lazy(() => import('./pages/Maintenance'));
const MaintenanceDetail = lazy(() => import('./pages/MaintenanceDetail'));
const Documents = lazy(() => import('./pages/Documents'));
const Utilities = lazy(() => import('./pages/Utilities'));
const UtilityDetail = lazy(() => import('./pages/UtilityDetail'));
const CouncilTax = lazy(() => import('./pages/CouncilTax'));
const Insurance = lazy(() => import('./pages/Insurance'));
const InsuranceDetail = lazy(() => import('./pages/InsuranceDetail'));
const MeterReadings = lazy(() => import('./pages/MeterReadings'));
const Household = lazy(() => import('./pages/Household'));
const Emergency = lazy(() => import('./pages/Emergency'));
const Search = lazy(() => import('./pages/Search'));
const Settings = lazy(() => import('./pages/Settings'));
const More = lazy(() => import('./pages/More'));
const Upgrade = lazy(() => import('./pages/Upgrade'));
const Admin = lazy(() => import('./pages/Admin'));
const Help = lazy(() => import('./pages/Help'));
const NotFound = lazy(() => import('./pages/NotFound'));
// Prototype-only menu; compiled out of the real apps.
const DemoMenu = import.meta.env.VITE_DEMO ? lazy(() => import('./demo/DemoControls')) : null;

function FullScreenSpinner() {
  return (
    <div className="flex min-h-dvh items-center justify-center">
      <Spinner />
    </div>
  );
}

function RequireAuth({ children }: { children: ReactNode }) {
  const { session, loading } = useAuth();
  const location = useLocation();
  if (loading) return <FullScreenSpinner />;
  if (!session) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  return <>{children}</>;
}

function PublicOnly({ children }: { children: ReactNode }) {
  const { session, loading } = useAuth();
  if (loading) return <FullScreenSpinner />;
  if (session) return <Navigate to="/" replace />;
  return <>{children}</>;
}

/** Pages that need an active property get the "add a property first" state for free. */
const p = (node: ReactNode) => <RequireProperty>{node}</RequireProperty>;

function AppRoutes() {
  return (
    <Suspense fallback={<FullScreenSpinner />}>
      <Routes>
        <Route
          path="/login"
          element={
            <PublicOnly>
              <Login />
            </PublicOnly>
          }
        />
        <Route
          path="/register"
          element={
            <PublicOnly>
              <Register />
            </PublicOnly>
          }
        />
        <Route
          path="/forgot-password"
          element={
            <PublicOnly>
              <ForgotPassword />
            </PublicOnly>
          }
        />
        <Route path="/reset-password" element={<ResetPassword />} />
        <Route
          element={
            <RequireAuth>
              <AppShell />
            </RequireAuth>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="properties" element={<Properties />} />
          <Route path="properties/:id" element={<PropertyDetail />} />
          <Route path="rooms" element={p(<Rooms />)} />
          <Route path="rooms/:id" element={p(<RoomDetail />)} />
          <Route path="appliances" element={p(<ItemsList kind="appliance" />)} />
          <Route path="appliances/:id" element={p(<ItemDetail kind="appliance" />)} />
          <Route path="inventory" element={p(<ItemsList kind="inventory" />)} />
          <Route path="inventory/:id" element={p(<ItemDetail kind="inventory" />)} />
          <Route path="warranties" element={p(<Warranties />)} />
          <Route path="maintenance" element={p(<Maintenance />)} />
          <Route path="maintenance/:id" element={p(<MaintenanceDetail />)} />
          <Route path="documents" element={p(<Documents />)} />
          <Route path="utilities" element={p(<Utilities />)} />
          <Route path="utilities/:id" element={p(<UtilityDetail />)} />
          <Route path="council-tax" element={p(<CouncilTax />)} />
          <Route path="insurance" element={p(<Insurance />)} />
          <Route path="insurance/:id" element={p(<InsuranceDetail />)} />
          <Route path="meter-readings" element={p(<MeterReadings />)} />
          <Route path="household" element={p(<Household />)} />
          <Route path="emergency" element={p(<Emergency />)} />
          <Route path="search" element={<Search />} />
          <Route path="settings" element={<Settings />} />
          <Route path="more" element={<More />} />
          <Route path="upgrade" element={<Upgrade />} />
          <Route path="admin" element={<Admin />} />
          <Route path="help" element={<Help />} />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </Suspense>
  );
}

// The prototype runs inside a sandboxed frame, so it keeps routes in memory.
// The Windows app has no address bar, so it uses #/routes, which survive a reload (F5).
const Router = import.meta.env.VITE_DEMO ? MemoryRouter : import.meta.env.MODE === 'desktop' ? HashRouter : BrowserRouter;

export default function App() {
  if (!isSupabaseConfigured) return <SetupRequired />;
  return (
    <Router>
      <ToastProvider>
        <AuthProvider>
          <CategoriesProvider>
            <PropertyProvider>
              <TourProvider>
                <AppRoutes />
                {DemoMenu && (
                  <Suspense fallback={null}>
                    <DemoMenu />
                  </Suspense>
                )}
              </TourProvider>
              <NativeBridge />
            </PropertyProvider>
          </CategoriesProvider>
        </AuthProvider>
      </ToastProvider>
    </Router>
  );
}
