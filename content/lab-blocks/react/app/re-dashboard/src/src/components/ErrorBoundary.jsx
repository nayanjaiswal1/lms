import { Component } from 'react';

/** Catches errors thrown while rendering its children and shows a fallback. */
export default class ErrorBoundary extends Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error) {
    console.error('page crashed:', error);
  }

  render() {
    if (this.state.failed) {
      return <p role="alert">Something went wrong on this page. Reload to try again.</p>;
    }
    return this.props.children;
  }
}
