import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { ChangeAdminUserRoleDto } from './change-admin-user-role.dto';

describe('ChangeAdminUserRoleDto', () => {
  it.each(['USER', 'ADMIN'])('accepts %s without city assignments', async (role) => {
    const dto = plainToInstance(ChangeAdminUserRoleDto, { role });
    expect(await validate(dto)).toHaveLength(0);
  });

  it('accepts CITY_ADMIN with unique bounded city assignments', async () => {
    const dto = plainToInstance(ChangeAdminUserRoleDto, { role: 'CITY_ADMIN', cityIds: ['pune', 'mumbai'] });
    expect(await validate(dto)).toHaveLength(0);
  });

  it('rejects duplicate, excessive or malformed city assignments', async () => {
    for (const cityIds of [['pune', 'pune'], Array.from({ length: 21 }, (_, i) => 'city-' + i), ['']]) {
      const dto = plainToInstance(ChangeAdminUserRoleDto, { role: 'CITY_ADMIN', cityIds });
      expect(await validate(dto)).not.toHaveLength(0);
    }
  });

  it('rejects unsupported roles', async () => {
    const dto = plainToInstance(ChangeAdminUserRoleDto, { role: 'SUPER_ADMIN' });
    expect(await validate(dto)).not.toHaveLength(0);
  });
});
