import { Controller, Get, Query } from '@nestjs/common';
import { cityCatalogueForLanguage } from './city-catalogue';

@Controller('cities')
export class CitiesController {
  @Get()
  list(@Query('language') language?: string) {
    return cityCatalogueForLanguage(language);
  }
}
