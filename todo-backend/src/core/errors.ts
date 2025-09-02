export class AppError extends Error {
  status: number;
  violations?: any[];
  constructor(message: string, status = 400, violations?: any[]) {
    super(message);
    this.status = status;
    this.violations = violations;
  }
}

export class BadRequestError extends AppError { constructor(message: string, violations?: any[]) { super(message, 400, violations) } }
export class NotFoundError extends AppError { constructor(message: string) { super(message, 404) } }
export class ValidationError extends AppError { constructor(violations: any[]) { super("validation failed", 422, violations) } }

