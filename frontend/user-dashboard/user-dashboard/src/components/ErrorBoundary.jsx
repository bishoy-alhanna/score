import React from 'react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props)
    this.state = { hasError: false, error: null, errorInfo: null }
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error }
  }

  componentDidCatch(error, errorInfo) {
    console.error('============ ERROR BOUNDARY CAUGHT ERROR ============')
    console.error('Error:', error)
    console.error('Error Message:', error.message)
    console.error('Error Stack:', error.stack)
    console.error('Component Stack:', errorInfo.componentStack)
    console.error('====================================================')
    this.setState({ errorInfo })
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
          <div className="max-w-2xl w-full space-y-4">
            <Alert variant="destructive">
              <AlertDescription>
                <div className="space-y-2">
                  <p className="font-bold">Something went wrong. The application encountered an unexpected error.</p>
                  {this.state.error && (
                    <details className="mt-4 text-sm">
                      <summary className="cursor-pointer font-semibold">Click to see error details</summary>
                      <div className="mt-2 p-3 bg-gray-100 rounded overflow-auto max-h-96">
                        <pre className="text-xs whitespace-pre-wrap">
                          <strong>Error:</strong> {this.state.error.toString()}
                          {'\n\n'}
                          <strong>Stack:</strong>{'\n'}{this.state.error.stack}
                          {this.state.errorInfo && (
                            <>
                              {'\n\n'}
                              <strong>Component Stack:</strong>{'\n'}{this.state.errorInfo.componentStack}
                            </>
                          )}
                        </pre>
                      </div>
                    </details>
                  )}
                </div>
              </AlertDescription>
            </Alert>
            <Button 
              onClick={() => {
                this.setState({ hasError: false, error: null, errorInfo: null })
                window.location.reload()
              }}
              className="w-full"
            >
              Reload Application
            </Button>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}

export default ErrorBoundary