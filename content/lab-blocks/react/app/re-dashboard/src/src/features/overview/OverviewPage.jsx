import { useSettings } from '../../context/settings.jsx';

export default function OverviewPage() {
  const { currency } = useSettings();
  return (
    <section aria-labelledby="overview-title">
      <h2 id="overview-title">Overview</h2>
      <p>Support tools for the shop: orders, customers, order notes and revenue reports.</p>
      <p>Amounts are shown in {currency}.</p>
    </section>
  );
}
