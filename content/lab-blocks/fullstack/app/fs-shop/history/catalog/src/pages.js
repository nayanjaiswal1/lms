import WelcomePage from './features/welcome/WelcomePage.jsx';
import OrdersPage from './features/orders/OrdersPage.jsx';
import CatalogPage from './features/catalog/CatalogPage.jsx';

// Pages shown in the main navigation, in order. Each feature adds its own.
export const PAGES = [
  { id: 'welcome', title: 'Welcome', Component: WelcomePage },
  { id: 'catalog', title: 'Catalog', Component: CatalogPage },
  { id: 'orders', title: 'Orders', Component: OrdersPage },
];
