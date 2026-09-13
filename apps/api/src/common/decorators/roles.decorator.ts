import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'vibetable_roles';
export const Roles = (...roles: Array<'player' | 'moderator' | 'admin'>) => SetMetadata(ROLES_KEY, roles);
