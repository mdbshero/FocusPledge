/**
 * Structured logging utility for Cloud Functions
 *
 * Outputs JSON-formatted logs compatible with Google Cloud Logging.
 * Each log entry includes a severity level, function context, and structured data.
 */

type Severity = 'DEBUG' | 'INFO' | 'WARNING' | 'ERROR';

interface LogEntry {
  severity: Severity;
  message: string;
  function?: string;
  userId?: string;
  sessionId?: string;
  [key: string]: unknown;
}

function emitLog(entry: LogEntry): void {
  const output = {
    ...entry,
    timestamp: new Date().toISOString(),
  };

  switch (entry.severity) {
    case 'ERROR':
      console.error(JSON.stringify(output));
      break;
    case 'WARNING':
      console.warn(JSON.stringify(output));
      break;
    default:
      console.log(JSON.stringify(output));
  }
}

export const logger = {
  info(message: string, data: Omit<LogEntry, 'severity' | 'message'> = {}): void {
    emitLog({ severity: 'INFO', message, ...data });
  },
  warn(message: string, data: Omit<LogEntry, 'severity' | 'message'> = {}): void {
    emitLog({ severity: 'WARNING', message, ...data });
  },
  error(message: string, data: Omit<LogEntry, 'severity' | 'message'> = {}): void {
    emitLog({ severity: 'ERROR', message, ...data });
  },
  debug(message: string, data: Omit<LogEntry, 'severity' | 'message'> = {}): void {
    emitLog({ severity: 'DEBUG', message, ...data });
  },
};
