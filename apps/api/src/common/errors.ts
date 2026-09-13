import { BadRequestException, ConflictException, ForbiddenException, NotFoundException, UnauthorizedException } from '@nestjs/common';

export const invalid = (message: string) => new BadRequestException(message);
export const unauthenticated = (message = 'Authentication is required.') => new UnauthorizedException(message);
export const forbidden = (message: string) => new ForbiddenException(message);
export const notFound = (message: string) => new NotFoundException(message);
export const conflict = (message: string) => new ConflictException(message);
