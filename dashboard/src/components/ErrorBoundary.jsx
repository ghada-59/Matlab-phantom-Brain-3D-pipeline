import { Component } from 'react';

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  render() {
    if (this.state.error) {
      return (
        <p role="alert">
          Cette vue n'a pas pu s'afficher. {this.state.error.message}
        </p>
      );
    }
    return this.props.children;
  }
}
