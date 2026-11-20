import { ArrayMaxSize, ArrayUnique, IsArray, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class ChangeAdminUserRoleDto {
  @IsIn(['USER', 'ADMIN', 'CITY_ADMIN'])
  role!: 'USER' | 'ADMIN' | 'CITY_ADMIN';

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MinLength(1, { each: true })
  @MaxLength(80, { each: true })
  cityIds?: string[];
}
