import OverviewPage from './features/overview/OverviewPage.jsx';
import OrdersPage from './features/orders/OrdersPage.jsx';
import CustomersPage from './features/customers/CustomersPage.jsx';
import NotesPage from './features/notes/NotesPage.jsx';

// Pages shown in the main navigation, in order. Each feature adds its own.
export const PAGES = [
  { id: 'overview', title: 'Overview', Component: OverviewPage },
  { id: 'orders', title: 'Orders', Component: OrdersPage },
  { id: 'customers', title: 'Customers', Component: CustomersPage },
  { id: 'notes', title: 'Order notes', Component: NotesPage },
];
