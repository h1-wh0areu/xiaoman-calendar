import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { seedDemo } from './seed';

async function bootstrap() {
  seedDemo();
  const app = await NestFactory.create(AppModule, { cors: true });
  app.setGlobalPrefix('v1');
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Xiaoman API http://localhost:${port}/v1  (dev SMS code 000000)`);
}

bootstrap();
