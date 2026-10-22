import { LegalPage, Seccion } from "@/components/LegalPage";

export default function PrivacidadPage() {
  return (
    <LegalPage title="Política de privacidad">
      <Seccion titulo="1. Quién es responsable de tus datos">
        <p>
          [Titular / razón social], con domicilio en [domicilio], es
          responsable del tratamiento de los datos personales en [Nombre de la
          app]. Contacto: [correo de contacto].
        </p>
      </Seccion>

      <Seccion titulo="2. Qué datos recolectamos">
        <ul className="list-disc pl-5">
          <li>De tu cuenta: nombre, correo electrónico y contraseña (se guarda cifrada).</li>
          <li>
            De tu perfil, si ofrecés servicios: rubro, descripción, país,
            provincia, ciudad, teléfono y WhatsApp.
          </li>
          <li>Documentos: certificados, matrículas o estudios que subas.</li>
          <li>Fotos de trabajos realizados.</li>
          <li>
            Referencias: nombre, detalle y teléfono de terceros que cargues,
            para los rubros de cuidado y seguridad.
          </li>
          <li>Calificaciones y comentarios que escribas o recibas.</li>
          <li>Denuncias que hagas y la evidencia que adjuntes.</li>
          <li>Datos técnicos mínimos para mantener tu sesión iniciada.</li>
        </ul>
      </Seccion>

      <Seccion titulo="3. Para qué los usamos">
        <ul className="list-disc pl-5">
          <li>Mostrar perfiles y permitir que te encuentren y contacten.</li>
          <li>Revisar documentos y mostrar la insignia de verificado.</li>
          <li>Mostrar calificaciones y calcular promedios.</li>
          <li>Revisar denuncias y proteger a la comunidad de fraudes.</li>
          <li>Mantener la seguridad y el funcionamiento de la plataforma.</li>
        </ul>
        <p>No vendemos tus datos.</p>
      </Seccion>

      <Seccion titulo="4. Quién puede ver qué">
        <p>
          <strong>Cualquier visitante, sin cuenta:</strong> nombre, rubro,
          ciudad, provincia y país, descripción, fotos de trabajos,
          calificaciones y comentarios, y la insignia de verificado.
        </p>
        <p>
          <strong>Usuarios con sesión iniciada:</strong> además, teléfono y
          WhatsApp, los títulos de los certificados verificados y las
          referencias de trabajos anteriores.
        </p>
        <p>
          <strong>Solo vos y los administradores:</strong> los archivos
          originales de tus documentos, que se guardan en un espacio privado.
        </p>
        <p>
          <strong>Denuncias:</strong> las ven quien denuncia y los
          administradores. No informamos a la persona denunciada quién hizo la
          denuncia, salvo requerimiento de autoridad competente.
        </p>
      </Seccion>

      <Seccion titulo="5. Con quién compartimos datos">
        <p>
          Usamos proveedores de servicios técnicos para alojar la web
          (Vercel) y para guardar la base de datos y los archivos (Supabase).
          Esos proveedores pueden almacenar información en servidores fuera de
          la Argentina.
        </p>
        <p>
          También podemos compartir información si una autoridad competente nos
          lo exige legalmente.
        </p>
        <p>
          [REVISAR CON ABOGADO: transferencia internacional de datos y
          contratos con proveedores.]
        </p>
      </Seccion>

      <Seccion titulo="6. Cuánto tiempo guardamos tus datos">
        <p>
          Mientras tu cuenta esté activa. Si pedís eliminarla, borramos tus
          datos, salvo la información que debamos conservar por motivos de
          seguridad o legales, como registros de denuncias.
        </p>
      </Seccion>

      <Seccion titulo="7. Tus derechos">
        <p>
          Podés pedir acceder a tus datos, corregirlos o eliminarlos
          escribiendo a [correo de contacto]. Si considerás que no cumplimos con
          la normativa de protección de datos personales, podés presentar un
          reclamo ante la Agencia de Acceso a la Información Pública (AAIP), que
          es el órgano de control de la Ley 25.326.
        </p>
      </Seccion>

      <Seccion titulo="8. Datos de terceros: las referencias">
        <p>
          Quienes cargan referencias garantizan que esas personas aceptaron que
          se publique su contacto. Si figurás como referencia y no querés que
          aparezca tu contacto, escribinos a [correo de contacto] y lo
          eliminamos.
        </p>
      </Seccion>

      <Seccion titulo="9. Seguridad">
        <p>
          Protegemos tus datos con acceso restringido, almacenamiento privado
          para los documentos y conexiones cifradas. Ningún sistema es
          completamente seguro, y no podemos garantizar una seguridad absoluta.
        </p>
      </Seccion>

      <Seccion titulo="10. Menores de edad">
        <p>
          [Nombre de la app] es solo para mayores de 18 años. No recolectamos
          datos de menores de forma intencional.
        </p>
      </Seccion>

      <Seccion titulo="11. Cookies">
        <p>
          Usamos únicamente lo necesario para mantener tu sesión iniciada. Por
          ahora no usamos cookies de publicidad ni de seguimiento. Si eso cambia,
          actualizaremos esta política.
        </p>
      </Seccion>

      <Seccion titulo="12. Cambios en esta política">
        <p>
          Podemos actualizar esta política. Si el cambio es importante, te lo
          avisaremos en la plataforma.
        </p>
        <p>[REVISAR CON ABOGADO: inscripción de la base de datos ante la AAIP.]</p>
      </Seccion>
    </LegalPage>
  );
}