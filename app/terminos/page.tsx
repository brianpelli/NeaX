import { LegalPage, Seccion } from "@/components/LegalPage";

export default function TerminosPage() {
  return (
    <LegalPage title="Términos y condiciones">
      <Seccion titulo="1. Qué es [Nombre de la app]">
        <p>
          [Nombre de la app] es una plataforma que permite a personas ofrecer
          sus oficios y servicios, y a otras personas encontrarlos y
          contactarlos. Somos un punto de encuentro: no somos empleadores de
          quienes ofrecen servicios, no prestamos esos servicios y no somos
          parte de los acuerdos que las personas hagan entre sí.
        </p>
        <p>
          No garantizamos la calidad, el precio, la seguridad ni el resultado de
          ningún trabajo.
        </p>
      </Seccion>

      <Seccion titulo="2. Tu cuenta">
        <ul className="list-disc pl-5">
          <li>Tenés que ser mayor de 18 años.</li>
          <li>Los datos que cargues tienen que ser verdaderos y actuales.</li>
          <li>Cada persona puede tener una sola cuenta.</li>
          <li>Sos responsable de cuidar tu contraseña y de lo que se haga con tu cuenta.</li>
        </ul>
      </Seccion>

      <Seccion titulo="3. Perfiles de quienes ofrecen servicios">
        <p>
          Quien ofrece un servicio es responsable de que la información de su
          perfil sea veraz, de que los documentos que sube sean auténticos y le
          pertenezcan, y de no hacerse pasar por otra persona.
        </p>
        <p>
          La insignia “Verificado” significa que revisamos un documento
          aportado por la persona. No garantiza que tenga matrícula o
          habilitación vigente ante las autoridades competentes, ni su
          idoneidad. Te recomendamos confirmar esos datos por tu cuenta, por
          ejemplo consultando al colegio o ente que otorga la matrícula.
        </p>
      </Seccion>

      <Seccion titulo="4. Acuerdos entre personas">
        <p>
          Los precios, los pagos, los plazos y las condiciones del trabajo se
          acuerdan directamente entre las personas, fuera de [Nombre de la app].
          No intervenimos en esos acuerdos ni en los pagos.
        </p>
        <p>
          Antes de contratar, te sugerimos pedir un presupuesto, leer las
          calificaciones, no adelantar sumas importantes y tomar precauciones
          cuando el trabajo implique que alguien ingrese a tu casa o cuide a
          otra persona.
        </p>
      </Seccion>

      <Seccion titulo="5. Servicios que requieren habilitación">
        <p>
          Quien ofrezca servicios que exigen matrícula, habilitación o permisos
          (por ejemplo, instalaciones de gas, electricidad, seguridad privada o
          elaboración y venta de alimentos) es el único responsable de contar
          con ellos y de cumplir las normas que correspondan.
        </p>
      </Seccion>

      <Seccion titulo="6. Calificaciones y comentarios">
        <ul className="list-disc pl-5">
          <li>Solo puede calificar quien indicó que contrató a esa persona.</li>
          <li>Las calificaciones tienen que reflejar una experiencia real.</li>
          <li>
            No se permiten insultos, amenazas ni datos personales de terceros.
          </li>
          <li>
            Podemos ocultar o eliminar contenido que incumpla estos términos.
            Las calificaciones enviadas no se pueden editar.
          </li>
        </ul>
      </Seccion>

      <Seccion titulo="7. Referencias de trabajos anteriores">
        <p>
          En los rubros de cuidado de personas y seguridad, quien ofrece el
          servicio puede cargar contactos de referencia. Son referencias
          declaradas por esa persona y no las verificamos. Quien las carga
          garantiza que cada persona aceptó que se publique su contacto.
        </p>
      </Seccion>

      <Seccion titulo="8. Conductas prohibidas">
        <ul className="list-disc pl-5">
          <li>Estafar, engañar o hacerse pasar por otra persona.</li>
          <li>Subir documentos falsos o ajenos.</li>
          <li>Publicar contenido ilegal, ofensivo o que viole derechos de terceros.</li>
          <li>
            Usar los datos de contacto de otras personas para fines distintos de
            contratar un servicio, como enviar publicidad no solicitada.
          </li>
          <li>Copiar de forma automática los perfiles o interferir con el funcionamiento de la plataforma.</li>
        </ul>
      </Seccion>

      <Seccion titulo="9. Denuncias y suspensiones">
        <p>
          Cualquier persona con sesión iniciada puede denunciar un perfil y
          adjuntar evidencia. Revisamos las denuncias y, si hay indicios de
          incumplimiento, podemos suspender un perfil de forma preventiva
          mientras analizamos el caso. Un perfil suspendido deja de aparecer en
          las búsquedas.
        </p>
        <p>
          Si tu perfil fue suspendido, podés escribirnos a [correo de contacto]
          para dar tu versión. Si se aclara el caso, lo reactivamos. Las
          denuncias falsas o hechas de mala fe pueden dar lugar a la suspensión
          de la cuenta de quien las hace.
        </p>
        <p>
          [REVISAR CON ABOGADO: plazos y procedimiento de respuesta ante una
          suspensión.]
        </p>
      </Seccion>

      <Seccion titulo="10. Lo que subís a la plataforma">
        <p>
          Seguís siendo titular de tus textos y fotos. Nos das permiso para
          mostrarlos dentro de [Nombre de la app] mientras tu cuenta esté
          activa, con el único fin de prestar el servicio. Declarás que tenés
          derecho a subir ese contenido.
        </p>
      </Seccion>

      <Seccion titulo="11. Responsabilidad">
        <p>
          [Nombre de la app] se ofrece tal como está, sin garantías de
          funcionamiento ininterrumpido. En la medida permitida por la ley, no
          somos responsables por los daños que surjan de los acuerdos o el
          trato entre usuarios.
        </p>
        <p>
          [REVISAR CON ABOGADO: alcance de esta limitación a la luz de la Ley
          de Defensa del Consumidor y de la responsabilidad de las plataformas.]
        </p>
      </Seccion>

      <Seccion titulo="12. Cambios en estos términos">
        <p>
          Podemos modificar estos términos. Si el cambio es importante, te lo
          vamos a avisar en la plataforma. Seguir usando [Nombre de la app]
          después del aviso implica que aceptás la nueva versión.
        </p>
      </Seccion>

      <Seccion titulo="13. Ley aplicable y contacto">
        <p>
          Estos términos se rigen por las leyes de la República Argentina.
          Cualquier conflicto se somete a los tribunales de [ciudad y provincia
          de jurisdicción]. [REVISAR CON ABOGADO.]
        </p>
        <p>
          Titular de la plataforma: [Titular / razón social], domicilio
          [domicilio]. Contacto: [correo de contacto].
        </p>
      </Seccion>
    </LegalPage>
  );
}