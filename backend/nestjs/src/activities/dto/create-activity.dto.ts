import { ArrayUnique, IsArray, IsDateString, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateActivityDto {
  @IsString() @MinLength(1) @MaxLength(120) title!: string;
  @IsString() @MinLength(1) @MaxLength(10000) description!: string;
  @IsString() @MinLength(1) @MaxLength(80) cityId!: string;
  @IsDateString() startsAt!: string;
  @IsOptional() @IsDateString() endsAt?: string;
  @IsOptional() @IsArray() @ArrayUnique() @IsString({ each: true }) organisationIds?: string[];
}
