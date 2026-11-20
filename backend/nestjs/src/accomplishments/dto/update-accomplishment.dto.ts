import { ArrayUnique, IsArray, IsDateString, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateAccomplishmentDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(120) title?: string;
  @IsOptional() @IsString() @MinLength(1) @MaxLength(10000) description?: string;
  @IsOptional() @IsDateString() achievedAt?: string;
  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) organisationIds?: string[];
  @IsOptional() @IsIn(['DRAFT', 'PUBLISHED', 'ARCHIVED']) status?: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
}
