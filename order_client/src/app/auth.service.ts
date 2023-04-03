import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpErrorResponse } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private baseUrl = 'http://your-api-url.com/auth/get_jwt';

  constructor(private http: HttpClient) { }

  getJwtToken(username: string, password: string): Observable<any> {
    const headers = new HttpHeaders()
      .set('user', username)
      .set('password', password);

    return this.http.get(this.baseUrl, { headers });
  }
}
