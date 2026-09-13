import { ArgumentMetadata, Injectable, PipeTransform } from '@nestjs/common';

@Injectable()
export class TrimStringsPipe implements PipeTransform {
  transform(value: unknown, _metadata: ArgumentMetadata): unknown {
    if (Array.isArray(value)) return value.map((item) => this.transform(item, _metadata));
    if (!value || typeof value !== 'object') return typeof value === 'string' ? value.trim() : value;
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, this.transform(item, _metadata)]));
  }
}
